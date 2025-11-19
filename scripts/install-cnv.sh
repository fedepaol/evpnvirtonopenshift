#!/bin/bash -xe                                                                                                                                   
                                                                                                                                                  
cat <<EOF | oc apply -f -
apiVersion: v1                                                           
kind: Namespace
metadata:
  name: openshift-cnv
---                      
apiVersion: operators.coreos.com/v1
kind: OperatorGroup 
metadata:
  name: kubevirt-hyperconverged-group
  namespace: openshift-cnv
spec:
  targetNamespaces:
    - openshift-cnv                                                      
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: hco-operatorhub
  namespace: openshift-cnv
spec:
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  name: kubevirt-hyperconverged
  startingCSV: kubevirt-hyperconverged-operator.v4.20.0
  channel: "stable"
EOF

while ! oc api-resources |grep HyperConverged; do
    sleep 1
done

cat <<EOF | oc apply -f -
apiVersion: hco.kubevirt.io/v1beta1
kind: HyperConverged
metadata:
  name: kubevirt-hyperconverged
  namespace: openshift-cnv
spec:
  featureGates:
    primaryUserDefinedNetworkBinding: true
    deployKubevirtIpamController: true
EOF

oc wait HyperConverged kubevirt-hyperconverged -n openshift-cnv --for condition=Available --timeout=30m

