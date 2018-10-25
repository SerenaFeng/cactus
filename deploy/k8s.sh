#!/usr/bin/env bash

KUBE_DIR=/home/cactus/.kube
KUBE_EXC="kubectl --kubeconfig ${KUBE_DIR}/config"
KUBE_JOIN=""

function wait_ready {
  vnode=${1}

  for vn in "${vnodes[@]}"; do
    if is_master ${vnode};then
      master=$(get_node_ip ${vn})
      break
    fi
  done

  echo "Wait for ${vnode} to be ready ....."
  total_attempts=120
  sleep_time=15
  for attempt in $(seq "${total_attempts}"); do
    ssh ${SSH_OPTS} cactus@${master} bash -s -e << WAIT_READY
    ${KUBE_EXC} get node ${vnode} | tail -1 | grep -v NotReady | grep Ready
WAIT_READY
    case $? in
      0) echo "${attempt}> Success"; break ;;
      *) echo "${attempt}/${total_attempts}> master ain't ready yet, waiting for ${sleep_time} seconds ..." ;;
    esac
    sleep ${sleep_time}
  done
}

function deploy_master {
  for vnode in "${vnodes[@]}"; do
    if is_master ${vnode}; then
      echo "Begin deploying master ${vnode} at ...... `date`"
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

      echo -n "Deploy k8s with kubeadm, this will take a few minutes, please wait..."
      sudo kubeadm init --node-name ${vnode} --pod-network-cidr 10.244.0.1/16 --kubernetes-version v1.12.1

      echo -n "Configure kubectl"
      mkdir -p ${KUBE_DIR}
      sudo cp -f /etc/kubernetes/admin.conf ${KUBE_DIR}/config
      sudo chown 1000:1000 ${KUBE_DIR}/config
      ${KUBE_EXC} taint nodes --all node-role.kubernetes.io/master-

      echo -n "Apply CNI..."
      ${KUBE_EXC} apply -f https://raw.githubusercontent.com/SerenaFeng/cactus/master/kube-config/calico/rbac-kdd.yaml
      ${KUBE_EXC} apply -f https://raw.githubusercontent.com/SerenaFeng/cactus/master/kube-config/calico/calico.yaml
DEPLOY_END

      wait_ready ${vnode}
      echo "Finish deploying master ${vnode} at ...... `date`"
    fi
  done
}

function deploy_minion {
  for vnode in "${vnodes[@]}"; do
    [[ $(is_master ${vnode}) ]] || {
      echo "Begin deploying minion ${vnode} ... at `date`"

      echo "Finish deploying minion ${vnode} ... at `date`"
    }
  done
}
