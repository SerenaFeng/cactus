#!/usr/bin/env bash

[[ "${CI_DEBUG}" =~ (false|0) ]] || set -x

function parse_components {
  set +x
  compgen -v |
  while read var; do {
    [[ ${var} =~ cluster_states_components_ ]] && [[ -n ${!var} ]] && echo ${!var}
  }
  done || true
  [[ "${CI_DEBUG}" =~ (false|0) ]] || set -x
}

function parse_cni {
  set +x
  compgen -v |
  while read var; do {
    [[ ${var} =~ cluster_states_cni_ ]] && [[ -n ${!var} ]] && echo ${!var}
  }
  done || true
  [[ "${CI_DEBUG}" =~ (false|0) ]] || set -x
}


function master_exc {
  ssh_exc $(get_master) "$@"
}

function get_kube_join {
  KUBE_JOIN=$(master_exc "sudo kubeadm token create --print-join-command")
}

function deploy_master {
  local KUBE_DIR=/home/cactus/.kube
  for vnode in "${vnodes[@]}"; do
    if is_master ${vnode}; then
      args="--node-name ${vnode} --apiserver-advertise-address $(get_mgmt_ip ${vnode})"

      [[ -n ${cluster_domain} ]] && args="${args} --service-dns-domain ${cluster_domain}"
      [[ -n ${cluster_pod_cidr} ]] && args="${args} --pod-network-cidr ${cluster_pod_cidr}"
      [[ -n ${cluster_service_cidr} ]] && args="${args} --service-cidr ${cluster_service_cidr}"
      [[ -n ${cluster_version} ]] && args="${args} --kubernetes-version ${cluster_version}"

      echo "Begin deploying master ${vnode} ... "
      ssh ${SSH_OPTS} cactus@$(get_admin_ip ${vnode}) bash -s -e << DEPLOY_MASTER
        sudo -i
        set -ex

        echo -n "Make sure docker&kubelet is ready ..."
        groupadd docker
        usermod -aG docker cactus
        systemctl enable docker.service
        systemctl enable kubelet.service
        systemctl restart docker

        echo -n "Deploy k8s with kubeadm, this will take a few minutes, please wait ..."
        kubeadm init ${args}

        echo -n "Configure kubectl"
        exit
        set -ex
        mkdir -p ${KUBE_DIR}
        sudo cp -f /etc/kubernetes/admin.conf ${KUBE_DIR}/config
        sudo chown 1000:1000 ${KUBE_DIR}/config
        kubectl taint nodes --all node-role.kubernetes.io/master-
DEPLOY_MASTER
   fi
  done
}

function deploy_minion {
  get_kube_join
  echo "Kubeadm join command is: ${KUBE_JOIN}"

  for vnode in "${vnodes[@]}"; do
    if ! is_master ${vnode}; then
      echo "Begin deploying minion ${vnode} ..."

      ssh ${SSH_OPTS} cactus@$(get_admin_ip ${vnode}) bash -s -e << DEPLOY_MINION
        sudo -i
        set -ex

        echo -n "Make sure docker&kubelet is ready ..."
        groupadd docker
        usermod -aG docker cactus
        systemctl enable docker.service
        systemctl enable kubelet.service
        systemctl restart docker

        echo -n "Begin to join cluster"
        ${KUBE_JOIN} --node-name ${vnode}
DEPLOY_MINION
      fi
      echo "Finish deploying minion ${vnode} ... "
  done
  echo "All minions are deployed"
}

function deploy_cni {
  echo "Apply CNI ..."

  if [[ -z ${cluster_states_cni} ]] || [[ "${cluster_states_cni}" == 'None' ]]; then
    cluster_states_cni=calico
  fi
  master_exc "kubectl apply -f /home/cactus/kube-config/${cluster_states_cni}"
}

function wait_cluster_ready {
  local total_attempts=120
  local sleep_time=30

  set +e
  echo "Wait for cluster to be ready ....."
  for attempt in $(seq "${total_attempts}"); do
    master_exc "kubectl get nodes | grep -v NotReady | grep Ready"
    case $? in
      0) echo "${attempt}> Success"; break ;;
      *) echo "${attempt}/${total_attempts}> cluster ain't ready yet, waiting for ${sleep_time} seconds ..." ;;
    esac
    sleep ${sleep_time}
  done
  set -e
}

function deploy_components {
  [[ -n "${cluster_states_components[@]}" ]] && {
    for com in "${cluster_states_components[@]}"; do
      master_exc "kubectl apply -f /home/cactus/kube-config/${com}"
    done
  }
}
