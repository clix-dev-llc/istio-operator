/*
Copyright 2019 Banzai Cloud.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package gateways

import (
	"github.com/banzaicloud/istio-operator/pkg/resources/templates"
	apiv1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/intstr"
)

func (r *Reconciler) service(gw string) runtime.Object {
	return &apiv1.Service{
		ObjectMeta: templates.ObjectMeta(gatewayName(gw), labelSelector(gw), r.Config),
		Spec: apiv1.ServiceSpec{
			Type:     serviceType(gw),
			Ports:    servicePorts(gw),
			Selector: labelSelector(gw),
		},
	}
}

func servicePorts(gw string) []apiv1.ServicePort {
	switch gw {
	case "ingressgateway":
		return []apiv1.ServicePort{
			{Port: 80, TargetPort: intstr.FromInt(80), Name: "http2", NodePort: 31380},
			{Port: 443, Name: "https", NodePort: 31390},
			{Port: 31400, Name: "tcp", NodePort: 31400},
			{Port: 15011, TargetPort: intstr.FromInt(15011), Name: "tcp-pilot-grpc-tls"},
			{Port: 8060, TargetPort: intstr.FromInt(8060), Name: "tcp-citadel-grpc-tls"},
			{Port: 853, TargetPort: intstr.FromInt(853), Name: "tcp-dns-tls"},
			{Port: 15030, TargetPort: intstr.FromInt(15030), Name: "http2-prometheus"},
			{Port: 15031, TargetPort: intstr.FromInt(15031), Name: "http2-grafana"},
		}
	case "egressgateway":
		return []apiv1.ServicePort{
			{Port: 80, Name: "http2"},
			{Port: 443, Name: "https"},
		}
	}
	return []apiv1.ServicePort{}
}

func serviceType(gw string) apiv1.ServiceType {
	switch gw {
	case "ingressgateway":
		return apiv1.ServiceTypeLoadBalancer
	case "egressgateway":
		return apiv1.ServiceTypeClusterIP
	}
	return ""
}
