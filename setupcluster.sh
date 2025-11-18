#!/bin/bash
set -e

wait_for_pods() {
  local namespace=$1
  local selector=$2
  local attempts=0
  local max_attempts=30
  local sleep_time=10

  while [[ -z $(kubectl get pods -n "$namespace" -l "$selector" 2>/dev/null) ]]; do
    echo "pods in $namespace not found"
    sleep $sleep_time
    attempts=$((attempts+1))
    if [ $attempts -eq $max_attempts ]; then
      echo "failed to wait for pods to appear"
      exit 1
    fi
    echo "pods in $namespace found"
  done
}

export KUBECONFIG=/home/fpaoline/.kcli/clusters/fedecluster/auth/kubeconfig
kubectl patch networks.operator.openshift.io cluster --type json  -p '[{"op": "add", "path": "/spec/defaultNetwork/ovnKubernetesConfig/gatewayConfig/ipForwarding", "value": Global}]'
kubectl patch networks.operator.openshift.io cluster --type json  -p '[{"op": "add", "path": "/spec/defaultNetwork/ovnKubernetesConfig/gatewayConfig/routingViaHost", "value": true}]'

sleep 5


#kubectl label node fedecluster-ctlplane-0.karmalabs.corp k8s.ovn.org/egress-assignable=""


