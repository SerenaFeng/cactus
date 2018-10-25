#!/usr/bin/env bash

KUBE_DIR=/home/cactus/.kube
KUBE_EXC="kubectl --kubeconfig ${KUBE_DIR}/config"


function get_kube_join {
  KUBE_JOIN=$(master_exc "sudo kubeadm token create --print-join-command")
}

function master_exc {
  ssh_exc $(get_master) "$@"
}

function deploy_master {
  for vnode in "${vnodes[@]}"; do
    if is_master ${vnode}; then
      echo "Begin deploying master ${vnode} ... "
      ssh ${SSH_OPTS} cactus@$(get_node_ip ${vnode}) bash -s -e << DEPLOY_END
      sudo -i
      set -e
      set -x

      echo -n "Make sure docker&kubelet is ready ..."
      sudo groupadd docker
      sudo usermod -aG docker cactus
      sudo systemctl enable docker.service
      sudo systemctl enable kubelet.service
      sudo systemctl restart docker

      echo -n "Deploy k8s with kubeadm, this will take a few minutes, please wait ..."
      sudo kubeadm init --node-name ${vnode} --pod-network-cidr 10.244.0.1/16 --kubernetes-version v1.12.1

      echo -n "Configure kubectl"
      mkdir -p ${KUBE_DIR}
      sudo cp -f /etc/kubernetes/admin.conf ${KUBE_DIR}/config
      sudo chown 1000:1000 ${KUBE_DIR}/config
      ${KUBE_EXC} taint nodes --all node-role.kubernetes.io/master-
DEPLOY_END

   fi
  done
}

function deploy_minion {
   get_kube_join
   echo "Kubeadm join command is: ${KUBE_JOIN}"

   for vnode in "${vnodes[@]}"; do
     if ! is_master ${vnode}; then
       echo "Begin deploying minion ${vnode} ..."

       ssh ${SSH_OPTS} cactus@$(get_node_ip ${vnode}) bash -s -e << DEPLOY_END
         sudo -i
         set -e
         set -x

         echo -n "Make sure docker&kubelet is ready ..."
         sudo groupadd docker
         sudo usermod -aG docker cactus
         sudo systemctl enable docker.service
         sudo systemctl enable kubelet.service
         sudo systemctl restart docker

         echo -n "Begin to join cluster"
         sudo ${KUBE_JOIN} --node-name ${vnode}
DEPLOY_END
      fi
      echo "Finish deploying minion ${vnode} ... "
  done
  echo "All minions are deployed"
}

function deploy_cni {
  echo "Apply CNI..."
  ssh ${SSH_OPTS} cactus@$(get_master) bash -s -e << DEPLOY_CNI_END
    ${KUBE_EXC} apply -f https://raw.githubusercontent.com/SerenaFeng/cactus/master/kube-config/calico/rbac-kdd.yaml
    ${KUBE_EXC} apply -f https://raw.githubusercontent.com/SerenaFeng/cactus/master/kube-config/calico/calico.yaml
DEPLOY_CNI_END
}

function wait_cluster_ready {
  local total_attempts=120
  local sleep_time=30

  echo "Wait for cluster to be ready ....."
  for attempt in $(seq "${total_attempts}"); do
    master_exc "${KUBE_EXC} get nodes | grep -v NotReady | grep Ready"
    case $? in
      0) echo "${attempt}> Success"; break ;;
      *) echo "${attempt}/${total_attempts}> cluster ain't ready yet, waiting for ${sleep_time} seconds ..." ;;
    esac
    sleep ${sleep_time}
  done
}
