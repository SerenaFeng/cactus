#!/usr/bin/env bash

REMOTE_KUBECONF=/home/cactus/.kube
LOCAL_KUBECONF=$HOME/.kube
LOCAL_KUBEDIR="${REPO_ROOT_PATH}/kube-config"
helm=$(which helm)

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
  local no_error=${2:-true}
  [[ ${ONSITE} -eq 0 ]] && {
    sudouser_exc "${cmdstr}" ${no_error}
  } || {
    master_exc "${cmdstr}"
  }
}

function kube_apply {
  [[ ${ONSITE} -eq 0 ]] && {
    sudouser_exc "kubectl apply -f ${LOCAL_KUBEDIR}/${1}"
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
        sudouser_exc "
          mkdir ${LOCAL_KUBECONF} || true
          rm -fr ${conf} || true
          scp ${SSH_OPTS} ${sshe}:${REMOTE_KUBECONF}/config ${LOCAL_KUBECONF} || true
        "
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
    kube_exc "kubectl get nodes | grep -v NotReady | grep Ready" false
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
      kube_apply ${obj}
    done
  } || true
}

function deploy_helm {
  [[ -n "${cluster_states_helm_version}" ]] && {
    ssh ${SSH_OPTS} cactus@$(get_master) bash -s -e << DEPLOY_HELM
      set -ex

      echo -n "Begin to install helm ..."
      curl https://raw.githubusercontent.com/kubernetes/helm/${cluster_states_helm_version}/scripts/get > ./get
      chmod +x ./get
      bash ./get -v ${cluster_states_helm_version}

      helm init --wait --service-account tiller || true
      helm repo remove stable || true
      helm version || true
DEPLOY_HELM

    [[ ${ONSITE} -eq 0 ]] && {
      echo "Init local helm client,for debug local chart ..."
      sudouser_exc "
        rm -fr ~/.helm
        helm init --client-only 
        helm repo remove stable
        helm version
      "
    }
  }

  [[ -n "${cluster_states_helm_repos[@]}" ]] && {
    echo -n "Begin to add repos ..."
    for repo in "${cluster_states_helm_repos[@]}"; do
      IFS='|' read -a repo_i <<< "${repo}"
      echo -n "Add repo: ${repo_i[0]}|${repo_i[1]}"
      master_exc "helm repo add ${repo_i[0]} ${repo_i[1]}" || true
    done
  } || true
 
  [[ -n "${cluster_states_helm_charts[@]}" ]] && {
    echo -n "Begin to install charts"
    for chart in "${cluster_states_helm_charts[@]}"; do
      IFS='|' read -a r_i <<< "${chart}"
      r_chart=${r_i[0]}
      [[ -n ${r_i[1]} ]] && r_name="--name ${r_i[1]}"
      [[ -n ${r_i[2]} ]] && r_version="--version ${r_i[2]}"
      [[ -n ${r_i[3]} ]] && {
        kube_exc "kubectl create namespace ${r_i[3]}" || true
        r_namespace="--namespace ${r_i[3]}"
      }
      echo -n "Install chart: ${r_i}"
      master_exc "helm install ${r_name} ${r_version} ${r_namespace} ${r_chart}" || true
    done
  } || true
}

