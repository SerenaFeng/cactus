#!/usr/bin/env bash

function install-calico() {
    curl -o $K8S_ROOT/rbac-kdd.yaml -O -L https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
    curl -o $K8S_ROOT/calico.yaml -O -L https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
    sed -i -e "s/192.168.0.0/${CLUSTER_CIDR}/" $K8S_ROOT/calico.yaml
    kubectl apply -f $K8S_ROOT/rbac-kdd.yaml
    kubectl apply -f $K8S_ROOT/calico.yaml
}
