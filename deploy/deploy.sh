#!/usr/bin/env bash

do_exit () {
    local RC=$?
    cleanup_mounts > /dev/null 2>&1
    if [ ${RC} -eq 0 ]; then
        notify_n "[OK] ZaaS: zaas installation finished succesfully!\n\n" 2
    else
        notify_n "[ERROR] ZaaS: zaas installation threw a fatal error!\n\n"
    fi
}

export TERM=xterm

# BEGIN of variables to customize
#
CI_DEBUG=${CI_DEBUG:-0}; [[ "${CI_DEBUG}" =~ (false|0) ]] || set -x
export REPO_ROOT_PATH=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")
export STORAGE_DIR=/var/cactus
DEPLOY_DIR=$(cd "${REPO_ROOT_PATH}/deploy"; pwd)
CACTUS_BRIDGES=('cactus_br')
BR_NAMES=('cactus_admin')
BASE_CONFIG_URI="file://${REPO_ROOT_PATH}/config"
LOCAL_IDF=${REPO_ROOT_PATH}/config/lab/basic/idf.yaml
SCENARIO=${REPO_ROOT_PATH}/config/scenario/virtual/k8s-calico-noha.yaml
DRY_RUN=${DRY_RUN:-0}
INFRA_CREATION_ONLY=${INFRA_CREATION_ONLY:-0}
NO_DEPLOY_ENVIRONMENT=${NO_DEPLOY_ENVIRONMENT:-0}
ERASE_ENV=${ERASE_ENV:-0}

source "${DEPLOY_DIR}/globals.sh"
source "${DEPLOY_DIR}/lib.sh"
source "${DEPLOY_DIR}/lib_template.sh"

# BEGIN of main
#
if [[ "$(sudo whoami)" != 'root' ]]; then
    notify_e "[ERROR] This script requires sudo rights!"
    exit 1
fi

mkdir -p ${STORAGE_DIR}

# Enable the automatic exit trap
trap do_exit SIGINT SIGTERM EXIT

pushd "${DEPLOY_DIR}" > /dev/null

if ! virsh list >/dev/null 2>&1; then
    notify_e "[ERROR] This script requires hypervisor access!"
fi

# Get required infra deployment data
set +x
eval "$(parse_yaml "${SCENARIO}")"
[[ "${CI_DEBUG}" =~ (false|0) ]] || set -x

export CLUSTER_DOMAIN=${cluster_domain}

# Map PDF networks 'admin' to bridge names
eval "$(parse_yaml "${LOCAL_IDF}")"
BR_NETS=( \
    "${idf_cactus_jumphost_fixed_ips_admin}" \
)

for ((i = 0; i < ${#BR_NETS[@]}; i++)); do
    br_jump=$(eval echo "\$idf_cactus_jumphost_bridges_${BR_NAMES[i]}")
    if [ -n "${br_jump}" ] && [ "${br_jump}" != 'None' ] && \
       [ -d "/sys/class/net/${br_jump}/bridge" ]; then
            notify_n "[OK] Bridge found for '${BR_NAMES[i]}': ${br_jump}\n" 2
            CACTUS_BRIDGES[${i}]="${br_jump}"
    elif [ -n "${BR_NETS[i]}" ]; then
        bridge=$(ip addr | awk "/${BR_NETS[i]%.*}./ {print \$NF; exit}")
        if [ -n "${bridge}" ] && [ -d "/sys/class/net/${bridge}/bridge" ]; then
            notify_n "[OK] Bridge found for net ${BR_NETS[i]%.*}.0: ${bridge}\n" 2
            CACTUS_BRIDGES[${i}]="${bridge}"
        fi
    fi
done
notify "[NOTE] Using bridges: ${CACTUS_BRIDGES[*]}\n" 2

# Infra setup
generate_ssh_key

build_images

parse_vnodes

prepare_vms
