#!/usr/bin/env bash

REMOTE_KUBECONF=/home/cactus/.kube
LOCAL_KUBECONF=$HOME/.kube
LOCAL_KUBEDIR="${REPO_ROOT_PATH}/kube-config"


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
  [[ ${ONSITE} -eq 0 ]] && {
    eval "${cmdstr}"
  } || {
    master_exc "${cmdstr}"
  }
}

function kube_apply {
  [[ ${ONSITE} -eq 0 ]] && {
    kubectl apply -f ${LOCAL_KUBEDIR}/${1}
  } || {
    master_exc "kubectl apply -f ${REMOTE_KUBECONF}/${1}"
  }
}

function render_service_cidr {
  [[ -n ${cluster_service_cidr} ]] && {
    echo "serviceSubnet: ${cluster_service_cidr}"
   }
}

function compose_kubeadm_config {
  template=${DEPLOY_DIR}/templates/kubeadm-${cluster_version%.*}.template
  vnode=${1}
  [[ -n ${cluster_pod_cidr} ]] && cluster_pod_cidr="10.244.0.0/16"

  eval "cat <<-EOF
$(<"${template}")
EOF" 2> /dev/null > ${TMP_DIR}/kubeadm.conf
}

function cal_nr_hugepages {
  vnode=${1}
  [[ $(eval echo "\$nodes_${vnode}_node_features") =~ hugepage ]] && {
    mem=$(eval echo "\$nodes_${vnode}_node_memory")
    nr_hugepages=$((${mem} * 1024 / 2048 / 2))
  } || nr_hugepages=0
  echo ${nr_hugepages}
}

function deploy_master {
  for vnode in "${vnodes[@]}"; do
    if is_master ${vnode}; then
      nr_hugepages=$(cal_nr_hugepages ${vnode})

      sshe="cactus@$(get_admin_ip ${vnode})"
      compose_kubeadm_config ${vnode}
      scp ${SSH_OPTS} ${TMP_DIR}/kubeadm.conf ${sshe}:/home/cactus

      echo "Begin deploying master ${vnode} ... "
      ssh ${SSH_OPTS} ${sshe} bash -s -e << DEPLOY_MASTER
        sudo -i
        set -ex

        echo -n "Make sure docker&kubelet is ready ..."
        [[ ${nr_hugepages} != 0 ]] && sysctl vm.nr_hugepages=${nr_hugepages}
        groupadd docker
        usermod -aG docker cactus
        systemctl enable docker.service
        systemctl enable kubelet.service
        systemctl restart docker

        echo -n "Deploy k8s with kubeadm, this will take a few minutes, please wait ..."
        kubeadm init --config /home/cactus/kubeadm.conf


        echo -n "Configure kubectl"
        exit
        set -ex
        mkdir -p ${REMOTE_KUBECONF}
        sudo cp -f /etc/kubernetes/admin.conf ${REMOTE_KUBECONF}/config
        sudo chown -R 1000:1000 ${REMOTE_KUBECONF}
        kubectl taint nodes --all node-role.kubernetes.io/master-
        kubectl label node ${vnode} role=master
DEPLOY_MASTER

      [[ ${ONSITE} -eq 0 ]] && {
        local conf=${LOCAL_KUBECONF}/config
        [[ ! -d ${LOCAL_KUBECONF} ]] && mkdir ${LOCAL_KUBECONF}
        [[ -f ${conf} ]] && rm -fr ${conf}
        scp ${SSH_OPTS} ${sshe}:${REMOTE_KUBECONF}/config ${LOCAL_KUBECONF}
        chown -R $(id -u ${SUDO_USER}):$(id -g ${SUDO_USER}) ${LOCAL_KUBECONF}
      }
    fi
  done
}

function deploy_minion {
  get_kube_join
  echo "Kubeadm join command is: ${KUBE_JOIN}"

  for vnode in "${vnodes[@]}"; do
    if ! is_master ${vnode}; then
      nr_hugepages=$(cal_nr_hugepages ${vnode})

      echo "Begin deploying minion ${vnode} ..."
      ssh ${SSH_OPTS} cactus@$(get_admin_ip ${vnode}) bash -s -e << DEPLOY_MINION
        sudo -i
        set -ex

        echo -n "Make sure docker&kubelet is ready ..."
        [[ ${nr_hugepages} != 0 ]] && sysctl vm.nr_hugepages=${nr_hugepages}
        groupadd docker
        usermod -aG docker cactus
        systemctl enable docker.service
        systemctl enable kubelet.service
        systemctl restart docker

        echo -n "Begin to join cluster"
        ${KUBE_JOIN} --node-name $(eval echo "\$nodes_${vnode}_hostname")
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

function deploy_objects {
  [[ -n "${cluster_states_objects[@]}" ]] && {
    for obj in "${cluster_states_objects[@]}"; do
      [[ ${obj} =~ "istio" ]] && {
        kube_apply istio/crds.yaml
        sleep 5
        # in case some objects deploy failed for the first time
        # due to the resources referenced are not created yet
        kube_apply istio/${obj}.yaml
        kube_apply istio/${obj}.yaml
        kube_exc "kubectl label namespace default istio-injection=enabled"
      } || {
        kube_apply ${obj}
      }
    done
  } || true
}

function deploy_helm {
  [[ -n "${cluster_states_helm_version}" ]] && {
    ssh ${SSH_OPTS} cactus@$(get_master) bash -s -e << DEPLOY_HELM
      sudo -i
      set -ex

      echo -n "Begin to install helm ..."
      curl https://raw.githubusercontent.com/kubernetes/helm/${cluster_states_helm_version}/scripts/get > ./get
      chmod +x ./get
      bash ./get -v ${cluster_states_helm_version}

      exit
      set -ex
      helm init --wait --service-account tiller
      helm repo remove stable || true
      helm version || true
DEPLOY_HELM
  } || true

}
