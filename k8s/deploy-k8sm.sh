#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

export APTGET="sudo apt-get"
export APTMARK="sudo apt-mark"
export APTKEY="sudo apt-key"
export ADDAPT="sudo add-apt-repository"

CONTAINER_RUNTIME=${CONTAINER_RUNTIME:-"docker"}
CLUSTER_CIDR=${CLUSTER_CIDR:-"10.244.0.0/16"}
NETWORK_PLUGIN=${NETWORK_PLUGIN:-"flannel"}
KUBERNTES_ROOT=$(dirname "${BASH_SOURCE}")


source ${KUBERNTES_ROOT}/instal-deps.sh
source ${KUBERNTES_ROOT}/prepare.sh
source ${KUBERNTES_ROOT}/cni.sh

function deploy-k8s() {
    sudo kubeadm init --pod-network-cidr 10.244.0.1/16 --kubernetes-version stable
}

function config-kubectl() {
    mkdir -p $HOME/.kube
    sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    kubectl taint nodes --all node-role.kubernetes.io/master-
}

function main() {
    swap-off
    install-docker
    install-kubetools
    deploy-k8s
    config-kubectl
    install-calico
}