#!/usr/bin/env bash

REMOTE_KUBECONF=/home/cactus/.kube
LOCAL_KUBECONF=$HOME/.kube.${PREFIX}
LOCAL_KUBEDIR="${REPO_ROOT_PATH}/kube-config"
REMOTE_KUBEDIR=/home/cactus/kube-config
LOCAL_HELMCONF=/home/.helm.${PREFIX}
HELM="$(which helm) --home ${LOCAL_HELMCONF}"

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
    sudouser_exc "kubectl --kubeconfig ${LOCAL_KUBECONF}/config ${cmdstr}" ${no_error}
  } || {
    master_exc "${cmdstr}"
  }
}

function kube_apply {
  [[ ${ONSITE} -eq 0 ]] && {
    sudouser_exc "kubectl --kubeconfig ${LOCAL_KUBECONF}/config apply -f ${LOCAL_KUBEDIR}/${1}"
  } || {
    master_exc "kubectl apply -f ${REMOTE_KUBEDIR}/${1}"
  }
}

function render_service_cidr {
  [[ -n ${cluster_service_cidr} ]] && {
    echo "serviceSubnet: ${cluster_service_cidr}"
   }
}

function render_cni_cidr {
  template=${LOCAL_KUBEDIR}/${1}/${1}.yaml.template
  eval "cat <<-EOF
$(<"${template}")
EOF" 2> /dev/null > ${LOCAL_KUBEDIR}/${1}/${1}.yaml
}

function compose_kubeadm_config {
  template=${TEMPLATE_DIR}/kubeadm-${cluster_version%.*}.template
  vnode=${1}
  [[ -n ${cluster_pod_cidr} ]] || cluster_pod_cidr="10.244.0.0/16"

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
        sudouser_exc "
          rm -fr ${HOME}/.kube || true
          rm -fr ${LOCAL_KUBECONF} || true
          mkdir ${LOCAL_KUBECONF} || true
          scp ${SSH_OPTS} ${sshe}:${REMOTE_KUBECONF}/config ${LOCAL_KUBECONF} || true
          ln -s ${LOCAL_KUBECONF} ${HOME}/.kube || true
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

  render_cni_cidr ${cluster_states_cni}

  kube_apply ${cluster_states_cni}
}

function wait_cluster_ready {
  local total_attempts=120
  local sleep_time=30

  set +e
  echo "Wait for cluster to be ready ....."
  for attempt in $(seq "${total_attempts}"); do
    kube_exc "get nodes | grep -v NotReady | grep Ready" false
    case $? in
      0) echo "${attempt}> Success"; break ;;
      *) echo "${attempt}/${total_attempts}> cluster ain't ready yet, waiting for ${sleep_time} seconds ..." ;;
    esac
    sleep ${sleep_time}
  done
  set -e

  for vnode in "${vnodes[@]}"; do
    read -r -a labels <<< $(parse_labels ${vnode})
    [[ -n "${labels[@]}" ]] && kube_exc "label node ${vnode} ${labels[@]}"
  done
}

function deploy_objects {
  [[ -n "${cluster_states_objects[@]}" ]] && {
    for obj in "${cluster_states_objects[@]}"; do
      kube_apply ${obj}
    done
  } || true
}

function wait_istio_init_ok {
  local total_attempts=120
  local sleep_time=1

  set +e
  echo "Wait for cluster to be ready ....."
  for attempt in $(seq "${total_attempts}"); do
    kube_exc "get crds | grep 'istio.io\|certmanager.k8s.io' | wc -l | grep 53" false
    case $? in
      0) echo "${attempt}> Istio init finish"; break ;;
      *) echo "${attempt}/${total_attempts}> Istio init ain't ready yet, waiting for ${sleep_time} seconds ..." ;;
    esac
    sleep ${sleep_time}
  done
  set -e
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
        KUBECONFIG=${LOCAL_KUBECONF}
        rm -fr ${LOCAL_HELMCONF}
        ${HELM} init --client-only
        ${HELM} repo remove stable
        ${HELM} version
      "
    }
  }

  [[ -n "${cluster_states_helm_repos[@]}" ]] && {
    echo -n "Begin to add repos ..."
    for repo in "${cluster_states_helm_repos[@]}"; do
      name=$(eval echo "\$cluster_states_helm_repos_${repo}_name")
      url=$(eval echo "\$cluster_states_helm_repos_${repo}_url")

      echo -n "Add repo: ${name}: ${url}"
      master_exc "helm repo add ${name} ${url}" || true
    done
  } || true
 
  [[ -n "${cluster_states_helm_charts[@]}" ]] && {
    echo -n "Begin to install charts"
    for chart in "${cluster_states_helm_charts[@]}"; do
      name=$(eval echo "\$cluster_states_helm_charts_${chart}_name")
      version=$(eval echo "\$cluster_states_helm_charts_${chart}_version")
      namespace=$(eval echo "\$cluster_states_helm_charts_${chart}_namespace")
      r_chart=$(eval echo "\$cluster_states_helm_charts_${chart}_url")
      args=$(eval echo "\$cluster_states_helm_charts_${chart}_args")
      [[ -n ${name} ]] && r_name="--name ${name}"
      [[ -n ${version} ]] && r_version="--version ${version}"
      [[ -n ${namespace} ]] && {
        kube_exc "create namespace ${namespace}" || true
        r_namespace="--namespace ${namespace}"
      }
      [[ -n ${args} ]] && {
        r_args=$(echo "${args//___/ }")
      }

      echo -n "Install chart: ${r_name} ${r_version} ${r_namespace} ${r_args} ${r_chart}"
      master_exc "helm install ${r_name} ${r_version} ${r_namespace} ${r_args} ${r_chart}" || true
      [[ ${name} =~ istio-init ]] && wait_istio_init_ok
    done
  } || true
}

