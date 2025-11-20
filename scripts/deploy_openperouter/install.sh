#!/bin/bash

helm repo add openperouter https://openperouter.github.io/openperouter

helm repo update
helm install openperouter openperouter/openperouter -f values.yaml -n openperouter-system --create-namespace

oc adm policy add-scc-to-user privileged -n openperouter-system -z openperouter-controller
oc adm policy add-scc-to-user privileged -n openperouter-system -z openperouter-perouter

kubectl -n openperouter-system wait --for condition=established --timeout=60s crd/l2vnis.openpe.openperouter.github.io
kubectl -n openperouter-system wait --for condition=established --timeout=60s crd/l3vnis.openpe.openperouter.github.io
kubectl -n openperouter-system wait --for condition=established --timeout=60s crd/underlays.openpe.openperouter.github.io
