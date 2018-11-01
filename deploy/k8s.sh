#!/usr/bin/env bash

REMOTE_KUBEDIR=/home/cactus/.kube
LOCAL_KUBEDIR="${REPO_ROOT_PATH}/kube-config"


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

function parse_labels {
  set +x
  local vnode=${1};shift
  local identity_="nodes_${vnode}_labels_"
  compgen -v |
  while read var; do {
    [[ ${var} =~ ${identity_} ]] && {
      echo ${var#${identity_}}=${!var}
    }
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

function kube_exc {
  local cmdstr=${1}
  if [ ${ONSITE} -eq 0 ]; then
    eval "${cmdstr}"
  else
    master_exc "${cmdstr}"
  fi
}

function kube_apply {
  if [ ${ONSITE} -eq 0 ]; then
    kubectl apply -f ${LOCAL_KUBEDIR}/${1}
  else
    master_exc "kubectl apply -f ${REMOTE_KUBEDIR}/${1}"
  fi
}

function deploy_master {
  for vnode in "${vnodes[@]}"; do
    if is_master ${vnode}; then
      args="--node-name $(eval echo "\$nodes_${vnode}_hostname")" 
      args="${args} --apiserver-advertise-address $(get_mgmt_ip ${vnode})"

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
        mkdir -p ${REMOTE_KUBEDIR}
        sudo cp -f /etc/kubernetes/admin.conf ${REMOTE_KUBEDIR}/config
        sudo chown 1000:1000 ${REMOTE_KUBEDIR}/config
        kubectl taint nodes --all node-role.kubernetes.io/master-
        kubectl label node ${vnode} role=master
DEPLOY_MASTER

      [[ ${ONSITE} -eq 0 ]] && {
        conf=~/.kube/config
        mkdir ~/.kube/
        [[ -f ${conf} ]] && rm -fr ${conf}
        scp ${SSH_OPTS} cactus@$(get_admin_ip ${vnode}):${REMOTE_KUBEDIR}/config ~/.kube/
      }
    fi
  done
}

function deploy_minion {
  get_kube_join
  echo "Kubeadm join command is: ${KUBE_JOIN}"

  for vnode in "${vnodes[@]}"; do
    if ! is_master ${vnode}; then
      echo "Begin deploying minion ${vnode} ..."
      args="--node-name $(eval echo "\$nodes_${vnode}_hostname")"
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
        ${KUBE_JOIN} ${args}
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

  kube_apply ${cluster_states_cni}
}

function wait_cluster_ready {
  local total_attempts=120
  local sleep_time=30

  set +e
  echo "Wait for cluster to be ready ....."
  for attempt in $(seq "${total_attempts}"); do
    kube_exc "kubectl get nodes | grep -v NotReady | grep Ready"
    case $? in
      0) echo "${attempt}> Success"; break ;;
      *) echo "${attempt}/${total_attempts}> cluster ain't ready yet, waiting for ${sleep_time} seconds ..." ;;
    esac
    sleep ${sleep_time}
  done
  set -e

  for vnode in "${vnodes[@]}"; do
    read -r -a labels <<< $(parse_labels ${vnode})
    [[ -n "${labels[@]}" ]] && kube_exc "kubectl label node ${vnode} ${labels[@]}"
  done
}

function deploy_components {
  [[ -n "${cluster_states_components[@]}" ]] && {
    for com in "${cluster_states_components[@]}"; do
      kube_apply ${com}

      # in case some objects deploy failed for the first time
      # due to the resources referenced are not created yet
      [[ ${com} =~ "istio" ]] && kube_apply ${com}

    done
  }
}
