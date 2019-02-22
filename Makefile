
# Image URL to use all building/pushing image targets
IMG ?= banzaicloud/istio-operator:latest

DEP_VERSION = 0.5.0
GOLANGCI_VERSION = 1.10.2
LICENSEI_VERSION = 0.0.7

KUSTOMIZE_BASE = config/default

all: test manager

.PHONY: check
check: test lint ## Run tests and linters

bin/golangci-lint: bin/golangci-lint-${GOLANGCI_VERSION}
	@ln -sf golangci-lint-${GOLANGCI_VERSION} bin/golangci-lint
bin/golangci-lint-${GOLANGCI_VERSION}:
	@mkdir -p bin
	curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | bash -s -- -b ./bin v${GOLANGCI_VERSION}
	@mv bin/golangci-lint $@

.PHONY: lint
lint: bin/golangci-lint ## Run linter
	@bin/golangci-lint run -v

bin/licensei: bin/licensei-${LICENSEI_VERSION}
	@ln -sf licensei-${LICENSEI_VERSION} bin/licensei
bin/licensei-${LICENSEI_VERSION}:
	@mkdir -p bin
	curl -sfL https://raw.githubusercontent.com/goph/licensei/master/install.sh | bash -s v${LICENSEI_VERSION}
	@mv bin/licensei $@

.PHONY: license-check
license-check: bin/licensei ## Run license check
	bin/licensei check
	./scripts/check-header.sh

.PHONY: license-cache
license-cache: bin/licensei ## Generate license cache
	bin/licensei cache

# Run tests
test: install-kubebuilder generate fmt vet manifests
	KUBEBUILDER_ASSETS="$${PWD}/bin/kubebuilder/bin" go test ./pkg/... ./cmd/... -coverprofile cover.out

# Build manager binary
manager: generate fmt vet
	go build -o bin/manager github.com/banzaicloud/istio-operator/cmd/manager

# Run against the configured Kubernetes cluster in ~/.kube/config
run: generate fmt vet
	go run ./cmd/manager/main.go

# Install kustomize
install-kustomize:
	@ if ! which bin/kustomize &>/dev/null; then\
		scripts/install_kustomize.sh;\
	fi

# Install kubebuilder
install-kubebuilder:
	@ if ! which bin/kubebuilder/bin/kubebuilder &>/dev/null; then\
		scripts/install_kubebuilder.sh;\
	fi

bin/dep: bin/dep-${DEP_VERSION}
	@ln -sf dep-${DEP_VERSION} bin/dep
bin/dep-${DEP_VERSION}:
	@mkdir -p bin
	curl https://raw.githubusercontent.com/golang/dep/master/install.sh | INSTALL_DIRECTORY=bin DEP_RELEASE_TAG=v${DEP_VERSION} sh
	@mv bin/dep $@

.PHONY: vendor
vendor: bin/dep ## Install dependencies
	bin/dep ensure -v -vendor-only

# Install CRDs into a cluster
install: manifests
	kubectl apply -f config/crds

# Deploy controller in the configured Kubernetes cluster in ~/.kube/config
deploy: install-kustomize
	kubectl apply -f config/crds
	kubectl apply -f config/manager/namespace.yaml
	./scripts/image_patch.sh ./config/default/manager_image_patch.yaml ${IMG}
	bin/kustomize build $(KUSTOMIZE_BASE) | kubectl apply -f -

# Generate manifests e.g. CRD, RBAC etc.
manifests:
	go run vendor/sigs.k8s.io/controller-tools/cmd/controller-gen/main.go all

# Run go fmt against code
fmt:
	go fmt ./pkg/... ./cmd/...

# Run go vet against code
vet:
	go vet ./pkg/... ./cmd/...

# Generate code
generate:
ifndef GOPATH
	$(error GOPATH not defined, please define GOPATH. Run "go help gopath" to learn more about GOPATH)
endif
	go generate ./pkg/... ./cmd/...

# Build the docker image
docker-build:
	docker build -f Dockerfile.dev . -t ${IMG}
	@echo "updating kustomize image patch file for manager resource"

# Push the docker image
docker-push:
	docker push ${IMG}
