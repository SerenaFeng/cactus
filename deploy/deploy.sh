#!/usr/bin/env bash

##############################################################################
# BEGIN of usage description
#
usage ()
{
cat << EOF
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
$(notify_i "$(basename "$0"): Deploy the Kubernetes on vms" 3)

$(notify_i "USAGE:" 2)
  $(basename "$0") -s scenario -p pod

$(notify_i "OPTIONS:" 2)
  -s  scenario short-name
  -p  Pod-name
  -h  help information

$(notify_i "Input parameters to the build script are:" 2)
-s Deployment-scenario, this points to a short deployment scenario name, which
   has to be defined in config directory (e.g. calico-noha).
-p POD name as defined in the configuration directory, e.g. pod2
-h Print this help information

$(notify_i "[NOTE] sudo & virsh priviledges are needed for this script to run" 3)

Example:
$(notify_i "sudo $(basename "$0") -p pod1 -s calico-noha" 2)
EOF
}


do_exit () {
  notify_n "[OK] Cactus: Kubernetes installation finished succesfully!\n\n" 2
}

export TERM=xterm

# BEGIN of variables to customize
#
CI_DEBUG=${CI_DEBUG:-0}; [[ "${CI_DEBUG}" =~ (false|0) ]] || set -x
REPO_ROOT_PATH=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")
DEPLOY_DIR=$(cd "${REPO_ROOT_PATH}/deploy"; pwd)
CONF_DIR=${REPO_ROOT_PATH}/config
STORAGE_DIR=/var/cactus

CPU_PASS_THROUGH=${CPU_PASS_THROUGH:-1}

mkdir -p ${STORAGE_DIR}

source "${DEPLOY_DIR}/globals.sh"
source "${DEPLOY_DIR}/lib.sh"
source "${DEPLOY_DIR}/vms.sh"
source "${DEPLOY_DIR}/k8s.sh"


##############################################################################
# BEGIN of main
#
set +x
while getopts "p:s:h" OPTION
do
    case $OPTION in
        p) TARGET_POD=${OPTARG} ;;
        s) SCENARIO=${OPTARG} ;;
        h) usage; exit 0 ;;
        *) notify_e "[ERROR] Arguments not according to new argument style\n" ;;
    esac
done
set -x

if [[ "$(sudo whoami)" != 'root' ]]; then
  notify_e "[ERROR] This script requires sudo rights!"
  exit 1
fi


# Enable the automatic exit trap
trap do_exit SIGINT SIGTERM EXIT

pushd "${DEPLOY_DIR}" > /dev/null

if ! virsh list >/dev/null 2>&1; then
  notify_e "[ERROR] This script requires hypervisor access!"
fi

# Infra setup
generate_ssh_key

build_images

parse_idf

parse_pdf

prepare_networks

prepare_vms

create_networks

create_vms "${CPU_PASS_THROUGH}"

update_admin_network

update_mgmt_network

start_vms

check_connection

deploy_master

deploy_minion

deploy_cni

wait_cluster_ready
