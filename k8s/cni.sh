#!/usr/bin/env bash

function install-cni() {
    kubectl apply -f $KUBECONF/$NETWORK_PLUGIN
}
