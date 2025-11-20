#!/bin/bash -xe

kubectl apply -f https://raw.githubusercontent.com/openperouter/openperouter/refs/heads/main/config/all-in-one/crio.yaml

oc adm policy add-scc-to-user privileged -n openperouter-system -z controller
oc adm policy add-scc-to-user privileged -n openperouter-system -z perouter

kubectl -n openperouter-system wait --for condition=established --timeout=60s crd/l2vni
kubectl -n openperouter-system wait --for condition=established --timeout=60s crd/l3vni
kubectl -n openperouter-system wait --for condition=established --timeout=60s crd/underlay

