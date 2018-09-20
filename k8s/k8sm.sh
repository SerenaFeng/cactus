#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

export APTGET="sudo apt-get"
export APTMARK="sudo apt-mark"
export APTKEY="sudo apt-key"
export ADDAPT="sudo add-apt-repository"

CLUSTER_CIDR=${CLUSTER_CIDR:-"10.244.0.0"}
NETWORK_PLUGIN=calico
MONITOR="metrics-server"
CSI_PLUGIN='hostpath'

export K8S_ROOT=$(dirname "${BASH_SOURCE}")
export REPO_DIR=$(dirname ${K8S_ROOT})
export KUBECONF=${REPO_DIR}/kube-config

function usage() {
    echo "usage:"
    echo "  -m <monitor>: choose the monitor, heapster or metrics-server, default is metrics-server"
    echo "  -n <cni plugin>: calico or flannel, default is calico"
    echo "  -s <csi plugin>: only support hostpath for now"
}

OPTIND=1
while getopts "h:m:n:s:" opt; do
    case "$opt" in
    h)
        usage
        exit 0
        ;;
    m)
        MONITOR=$OPTARG
        ;;
    n)
        NETWORK_PLUGIN=$OPTARG
        ;;
    s)
        CSI_PLUGIN=$OPTARG
        ;;
    *)
        echo "unsupported options : $opt"
        usage
        exit 0
    esac
done


source ${K8S_ROOT}/deps.sh
source ${K8S_ROOT}/prepare.sh
source ${K8S_ROOT}/cni.sh

function deploy-k8s() {
    sudo kubeadm init --pod-network-cidr 10.244.0.1/16 --kubernetes-version v1.10.7
}

function config-kubectl() {
    mkdir -p $HOME/.kube
    sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    kubectl taint nodes --all node-role.kubernetes.io/master-
}

function install-dashboard() {
    kubectl apply -f ${KUBECONF}/dashboard.yaml
}

function install-monitor() {
    kubectl apply -f ${KUBECONF}/$MONITOR
}

function install-csi() {
    kubectl apply -f ${KUBECONF}/$CSI_PLUGIN
}

function main() {
#    swap-off
#    install-docker
#    install-kubetools
    deploy-k8s
    config-kubectl
    install-cni
    install-dashboard
    if [[ $MONITOR != "noop" ]]; then
        install-monitor
    fi
    if [[ $CSI_PLUGIN != "noop" ]];then
        install-csi
    fi
}

main
