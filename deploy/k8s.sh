#!/usr/bin/env bash

CI_DEBUG=${CI_DEBUG:-0}; [[ "${CI_DEBUG}" =~ (false|0) ]] || set -x

for vnode in "${vnodes[@]}"; do
  ssh_vnode ${vnode} << DEPLOY_K8S_END
  if is_master ${vnode}; then
    echo -n "Make sure docker is started..."
    sudo systemctl restart docker

    echo -n "Deploy k8s with kubeadm, this will take a few minutes, please wait..."
    sudo kubeadm init --pod-network-cidr 10.244.0.1/16 --kubernetes-version v1.10.7

    echo -n "Configure kubectl"
    mkdir -p $HOME/.kube
    sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    kubectl taint nodes --all node-role.kubernetes.io/master-

    echo -n "Apply CNI..."
    kubectl apply -f https://raw.githubusercontent.com/SerenaFeng/cactus/master/kube-config/calico/rbac-kdd.yaml
    kubectl apply -f https://raw.githubusercontent.com/SerenaFeng/cactus/master/kube-config/calico/calico.yaml
  fi
DEPLOY_K8S_END
done