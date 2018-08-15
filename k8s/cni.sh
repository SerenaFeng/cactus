#!/usr/bin/env bash

function install-calico() {
    curl -O -L https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
    curl -O -L kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
    sed -i -e 's/192\.168/10.244/' calico.yaml
    kubectl apply -f rbac-kdd.yaml
    kubectl apply -f calico.yaml
}
