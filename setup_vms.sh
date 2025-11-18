#!/bin/bash
kcli delete -y plan fede
kcli create plan -f plan.yaml fede
kcli create cluster openshift --paramfile config.yaml --force fedecluster

export KUBECONFIG=/home/fpaoline/.kcli/clusters/fedecluster/auth/kubeconfig
kubectl patch networks.operator.openshift.io cluster --type json  -p '[{"op": "add", "path": "/spec/defaultNetwork/ovnKubernetesConfig/gatewayConfig/ipForwarding", "value": Global}]'
kubectl patch networks.operator.openshift.io cluster --type json  -p '[{"op": "add", "path": "/spec/defaultNetwork/ovnKubernetesConfig/gatewayConfig/routingViaHost", "value": true}]'

oc patch networks.operator.openshift.io cluster --type json  -p '[{"op": "add", "path": "/spec/additionalRoutingCapabilities", "value": {providers: ["FRR"]}}]'
oc patch networks.operator.openshift.io cluster --type json  -p '[{"op": "add", "path": "/spec/defaultNetwork/ovnKubernetesConfig/routeAdvertisements", "value": "Enabled"}]'

