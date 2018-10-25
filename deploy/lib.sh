#!/bin/bash -e
# shellcheck disable=SC2155,SC1001
##############################################################################
# Copyright (c) 2017 Mirantis Inc., Enea AB and others.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
#
# Library of shell functions
#

function generate_ssh_key {
  local cactus_ssh_key=$(basename "${SSH_KEY}")
  local user=${USER}
  if [ -n "${SUDO_USER}" ] && [ "${SUDO_USER}" != 'root' ]; then
    user=${SUDO_USER}
  fi

  if [ -f "${SSH_KEY}" ]; then
    cp "${SSH_KEY}" .
    ssh-keygen -f "${cactus_ssh_key}" -y > "${cactus_ssh_key}.pub"
  fi

  [ -f "${cactus_ssh_key}" ] || ssh-keygen -f "${cactus_ssh_key}" -N ''
  sudo install -D -o "${user}" -m 0600 "${cactus_ssh_key}" "${SSH_KEY}"
  sudo install -D -o "${user}" -m 0600 "${cactus_ssh_key}.pub" "${SSH_KEY}.pub"
}

function build_images {
  local builder_image=cactus/dib:latest
  local dib_name=cactus_image_builder
  local sshpub="${SSH_KEY}.pub"

  [[ "$(docker images -q ${builder_image} 2>/dev/null)" != "" ]] || {
    echo "build diskimage_builder image... "
    pushd ${REPO_ROOT_PATH}/docker/dib
    docker build -t ${builder_image} .
    popd
  }

  echo "Start DIB console named ${dib_name} service ... "
  docker run -it \
           --name ${dib_name} \
           -v ${STORAGE_DIR}:/imagedata \
           --privileged \
           --rm \
           ${builder_image} \
           bash /create_image.sh
}

function parse_vnodes {
  eval $(python ${REPO_ROOT_PATH}/deploy/parse_pdf.py -y ${REPO_ROOT_PATH}/config/lab/basic/lab.yaml 2>&1)
  IFS=':' read -a vnodes <<< "${nodes}"
}

function cleanup_vms {
  # clean up existing nodes
  for node in $(virsh list --name | grep -P 'cactus'); do
    virsh destroy "${node}"
  done
  for node in $(virsh list --name --all | grep -P 'cactus'); do
    virsh domblklist "${node}" | awk '/^.da/ {print $2}' | \
      xargs --no-run-if-empty -I{} sudo rm -f {}
    # TODO command 'undefine' doesn't support option --nvram
    virsh undefine "${node}" --remove-all-storage
  done
}

function prepare_vms {
  local image_dir=${STORAGE_DIR}

  cleanup_vms

  # Create vnode images and resize OS disk image for each foundation node VM
  for node in "${vnodes[@]}"; do
    if [ $(eval echo "\$nodes_${node}_enabled") == "True" ]; then
      if is_master ${node}; then
        echo "preparing for master vnode [${node}]"
        image="k8s/master.qcow2"
      else
        echo "preparing for minion vnode [${node}]"
        image="k8s/minion.qcow2"
      fi
      cp "${image_dir}/${image}" "${image_dir}/cactus_${node}.qcow2"
      disk_capacity="nodes_${node}_node_disk"
      qemu-img resize "${image_dir}/cactus_${node}.qcow2" ${!disk_capacity}
    fi
  done
}

function create_networks {
  local vnode_networks=("$@")
  # create required networks
  for net in "${vnode_networks[@]}"; do
    if virsh net-info "${net}" >/dev/null 2>&1; then
      virsh net-destroy "${net}" || true
      virsh net-undefine "${net}"
    fi
    # in case of custom network, host should already have the bridge in place
    if [ -f "net_${net}.xml" ] && [ ! -d "/sys/class/net/${net}/bridge" ]; then
      virsh net-define "net_${net}.xml"
      virsh net-autostart "${net}"
      virsh net-start "${net}"
    fi
  done
}

function create_vms {
  cpu_pass_through=$1; shift
  local vnode_networks=("$@")

  # AArch64: prepare arch specific arguments
  local virt_extra_args=""
  if [ "$(uname -i)" = "aarch64" ]; then
    # No Cirrus VGA on AArch64, use virtio instead
    virt_extra_args="$virt_extra_args --video=virtio"
  fi

  # create vms with specified options
  for vnode in "${vnodes[@]}"; do
    # prepare network args
    net_args=""
    for net in "${vnode_networks[@]}"; do
      net_args="${net_args} --network bridge=${net},model=virtio"
    done

    [ ${cpu_pass_through} -eq 1 ] && \
    cpu_para="--cpu host-passthrough" || \
    cpu_para=""

    # shellcheck disable=SC2086
    virt-install --name "cactus_${vnode}" \
    --memory $(eval echo "\$nodes_${vnode}_node_memory") \
    --vcpus $(eval echo "\$nodes_${vnode}_node_cpus")\
    ${cpu_para} --accelerate ${net_args} \
    --disk path="${STORAGE_DIR}/cactus_${vnode}.qcow2",format=qcow2,bus=virtio,cache=none,io=native \
    --os-type linux --os-variant none \
    --boot hd --vnc --console pty --autostart --noreboot \
    --noautoconsole \
    ${virt_extra_args}
  done
}

function update_admin_network {
  for vnode in "${vnodes[@]}"; do
    local admin_br="${idf_cactus_jumphost_bridges_admin}"
    local guest="cactus_${vnode}"
    local ip=$(get_node_ip ${vnode})
    local cmac=$(virsh domiflist ${guest} 2>&1| awk -v br=${admin_br} '/br/ {print $5; exit}')
    virsh net-update "${admin_br}" add ip-dhcp-host \
      "<host mac='${cmac}' name='${guest}' ip='${ip}'/>" --live --config
  done
}

function start_vms {
  # start vms
  for node in "${vnodes[@]}"; do
    virsh start "cactus_${node}"
    sleep $((RANDOM%5+1))
  done
}

function check_connection {
  local total_attempts=60
  local sleep_time=5

  set +e
  echo '[INFO] Attempting to get into master ...'

  # wait until ssh on master is available
  # shellcheck disable=SC2034
  for vnode in "${vnodes[@]}"; do
    if is_master ${vnode}; then
      for attempt in $(seq "${total_attempts}"); do
        ssh_vnode ${vnode} uptime
        case $? in
          0) echo "${attempt}> Success"; break ;;
          *) echo "${attempt}/${total_attempts}> ssh server ain't ready yet, waiting for ${sleep_time} seconds ..." ;;
        esac
        sleep $sleep_time
      done
    fi
  done
  set -e
}

function parse_yaml {
  local prefix=$2
  local s
  local w
  local fs
  s='[[:space:]]*'
  w='[a-zA-Z0-9_]*'
  fs="$(echo @|tr @ '\034')"
  sed -e 's|---||g' -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
      -e "s|^\($s\)\($w\)$s[:-]$s\(.*\)$s\$|\1$fs\2$fs\3|p" "$1" |
  awk -F"$fs" '{
  indent = length($1)/2;
  vname[indent] = $2;
  for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
          vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
          printf("%s%s%s=(\"%s\")\n", "'"$prefix"'",vn, $2, $3);
      }
  }' | sed 's/_=/+=/g'
}

function get_node_ip {
  local vnode=${1}
  local node_id=$(eval echo "\$nodes_${vnode}_node_id")
  echo $(eval echo "${idf_cactus_jumphost_fixed_ips_admin%.*}.${node_id}")
}

function ssh_vnode {
  local vnode=${1}; shift
  local cmdstr=${1}; shift
  ssh ${SSH_OPTS} cactus@$(get_node_ip ${vnode}) bash -s -e << SSH_EXE_END
    $cmdstr
SSH_EXE_END
}

function is_master {
  local vnode=${1}
  if [ $(eval echo "\$nodes_${vnode}_cloud_native_master") == "True" ]; then
    return 0
  else
    return 1
  fi
}

function wait_for {
  # Execute in a subshell to prevent local variable override during recursion
  (
    local total_attempts=$1; shift
    local cmdstr=$1; shift
    local fail_func=$1
    local sleep_time=10
    echo -e "\n[wait_for] Waiting for cmd to return success: ${cmdstr}"
    # shellcheck disable=SC2034
    for attempt in $(seq "${total_attempts}"); do
      echo "[wait_for] Attempt ${attempt}/${total_attempts%.*} for: ${cmdstr}"
      if [ "${total_attempts%.*}" = "${total_attempts}" ]; then
        # shellcheck disable=SC2015
        eval "${cmdstr}" && echo "[wait_for] OK: ${cmdstr}" && return 0 || true
      else
        ! (eval "${cmdstr}" || echo 'No response') |& tee /dev/stderr | \
          grep -Eq '(Not connected|No response|No return received)' && \
          echo "[wait_for] OK: ${cmdstr}" && return 0 || true
      fi

      sleep "${sleep_time}"

      if [ -n "$fail_func" ];then
        echo "!!! Fail process is: $fail_func"
        eval "$fail_func"
      fi
    done

    echo "[wait_for] ERROR: Failed after max attempts: ${cmdstr}"

    return 1

  )
}

export CACHE_ALL_FILE_IN_MASTER=/tmp/all_nodes
export CACHE_SAME_FILE_IN_MASTER=$(dirname ${CACHE_ALL_FILE_IN_MASTER})/same_nodes
export ALL_NODES_IN_MASTER=""
export SAME_NODES_IN_MASTER=""
function generate_all_and_same_nodes_in_master {

  set +x

  CACHE_DIR=$(dirname ${CACHE_ALL_FILE_IN_MASTER})/
  rm -fr ${CACHE_ALL_FILE_IN_MASTER}
  rm -fr ${CACHE_SAME_FILE_IN_MASTER} && touch ${CACHE_SAME_FILE_IN_MASTER}

  node_file_list=$(find ${CACHE_DIR} -name "*.reclass.nodeinfo")
  for node_file in ${node_file_list}; do
    node_name=$(basename $node_file .reclass.nodeinfo)

    if [ ! -f ${CACHE_ALL_FILE_IN_MASTER} ]; then
      echo "${node_name}" > ${CACHE_ALL_FILE_IN_MASTER}
    else
      echo " or ${node_name}" >> ${CACHE_ALL_FILE_IN_MASTER}
    fi

    node_file_bak=${node_file}.bak
    if [ ! -f ${node_file_bak} ]; then
      continue
    fi
    node_diff=$(echo "$(diff ${node_file} ${node_file_bak} -I timestamp)" | xargs)
    if [ -z "${node_diff}" ]; then
      echo " and not $node_name" >> ${CACHE_SAME_FILE_IN_MASTER}
    else
      diff ${node_file} ${node_file_bak} -I timestamp -y || true
    fi
  done

  echo "=== Generate all and same configuration nodes list:"
  export ALL_NODES_IN_MASTER="$(cat ${CACHE_ALL_FILE_IN_MASTER} | xargs )"
  export SAME_NODES_IN_MASTER="$(cat ${CACHE_SAME_FILE_IN_MASTER} | xargs )"
  echo "All nodes in master: [${ALL_NODES_IN_MASTER}]"
  echo "Same node in master: [${SAME_NODES_IN_MASTER}]"
  echo "=== Generate all and same nodes end ==="

}

function restore_model_files_in_master {

  set +x

  CACHE_DIR=$(dirname ${CACHE_ALL_FILE_IN_MASTER})/

  node_file_list_bak=$(find ${CACHE_DIR} -name "*.reclass.nodeinfo.bak")
  for node_file_bak in ${node_file_list_bak}; do
    node_file=${node_file_bak%.*}
    echo " Restore old reclass file [${node_file_bak}]->[${node_file}]"
    mv -f ${node_file_bak} ${node_file} || true
  done

}

CACHE_ALL_FILE_LOCAL_DIR=$(dirname ${CACHE_ALL_FILE_IN_MASTER})/
CACHE_SAME_FILE_LOCAL_DIR=$(dirname ${CACHE_SAME_FILE_IN_MASTER})/
CACHE_ALL_FILE_LOCAL=${CACHE_ALL_FILE_IN_MASTER}
CACHE_SAME_FILE_LOCAL=${CACHE_SAME_FILE_IN_MASTER}
export ALL_NODES_LOCAL=""
export SAME_NODES_LOCAL=""
function get_all_and_same_nodes_from_master {

  set +x

  rm -fr ${CACHE_ALL_FILE_LOCAL} ${CACHE_SAME_FILE_LOCAL}
  scp ${SSH_OPTS} ${SSH_SALT}:${CACHE_ALL_FILE_IN_MASTER} ${CACHE_ALL_FILE_LOCAL_DIR}
  scp ${SSH_OPTS} ${SSH_SALT}:${CACHE_SAME_FILE_IN_MASTER} ${CACHE_SAME_FILE_LOCAL_DIR}
  if [ -f ${CACHE_ALL_FILE_LOCAL} ]; then
    export ALL_NODES_LOCAL="$(cat ${CACHE_ALL_FILE_LOCAL} | xargs )"
  fi
  if [ -f ${CACHE_SAME_FILE_LOCAL} ]; then
    export SAME_NODES_LOCAL="$(cat ${CACHE_SAME_FILE_LOCAL} | xargs )"
  fi

  echo "=== Get all and same configuration nodes list:"
  echo "All local nodes: [${ALL_NODES_LOCAL}]"
  echo "Same local nodes: [${SAME_NODES_LOCAL}]"
  echo "=== Get all and same nodes locally end ==="

}

function restart_salt_service {

  service_minion=${1:-salt-minion}
  service_master=${2:-""}

  if [ -n "$(command -v apt-get)" ]; then
    sudo service ${service_minion} stop || true
    sudo service ${service_minion} start || true
    [[ -n "${service_master}" ]] && {
      sudo service ${service_master} stop || true
      sudo service ${service_master} start || true
    }
  else
    sudo systemctl stop ${service_minion}  || true
    sudo systemctl start ${service_minion} || true
    [[ -n "${service_master}" ]] && {
      sudo systemctl stop ${service_master}  || true
      sudo systemctl start ${service_master}  || true
    }
  fi

  echo "Restart ${service_minion} ${service_master} successfully!"

}

function deploy_k8sm {
  KUBE_DIR=/home/cactus/.kube
  KUBEXC="kubectl --kubeconfig ${KUBE_DIR}/config"
  for vnode in "${vnodes[@]}"; do
    if is_master ${vnode};then
      ssh ${SSH_OPTS} cactus@$(get_node_ip ${vnode}) bash -s -e << DEPLOY_K8S_END
      sudo -i
      set -e
      set -x

      KUBE_DIR=/home/cactus/.kube
      alias kubexc="kubectl --kubeconfig ${KUBE_DIR}/config"

      echo "Begin to deploy ${vnode} at ...... `date`"
      echo -n "Make sure docker&kubelet is ready..."
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
      ${KUBEXC} taint nodes --all node-role.kubernetes.io/master-

      echo -n "Apply CNI..."
      ${KUBEXC} apply -f https://raw.githubusercontent.com/SerenaFeng/cactus/master/kube-config/calico/rbac-kdd.yaml
      ${KUBEXC} apply -f https://raw.githubusercontent.com/SerenaFeng/cactus/master/kube-config/calico/calico.yaml
DEPLOY_K8S_END

      echo "Wait for Master to be ready....."
      total_attempts=60
      sleep_time=60
      for attempt in $(seq "${total_attempts}"); do
        ssh ${SSH_OPTS} cactus@$(get_node_ip ${vnode}) bash -s -e << WAIT_MASTER_READY
        ${KUBEXC} get node ${vnode} | tail -1 | grep -v NotReady | grep Ready
WAIT_MASTER_READY
        case $? in
          0) echo "${attempt}> Success"; break ;;
          *) echo "${attempt}/${total_attempts}> master ain't ready yet, waiting for ${sleep_time} seconds ..." ;;
        esac
        sleep ${sleep_time}
      done
      echo "Finish deploying ${vnode} at ...... `date`"
    fi
  done
}

