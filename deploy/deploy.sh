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
  -P  VM prefix, \${prefix}_<nodename>
  -l  cleanup level dib or sto or vms
  -r  Use onsite kube-config
  -h  help information

$(notify_i "Input parameters to the build script are:" 2)
-s Deployment-scenario, this points to a short deployment scenario name, which
   has to be defined in config directory (e.g. calico-noha).
-p POD name as defined in the configuration directory, e.g. pod2
-P Prefix of vm name, e.g. if prefix=cactus, vm name will be cactus_<node name>
-l cleanup level dib=all resources, sto=all resources except dib image, vms=only delete vms and networks
-r Choose to use on-site(configs on the master vm) or local kube-config directory
-h Print this help information

$(notify_i "[NOTE] sudo & virsh priviledges are needed for this script to run" 3)

Example:
$(notify_i "sudo $(basename "$0") -p pod1 -s calico-noha" 2)
EOF
}


do_exit () {
  if [[ 0 == $? ]]; then
    notify_n "[OK] Cactus: Kubernetes installation finished succesfully!\n\n" 2
  else
    notify_n "[KO] Cactus: Kubernetes installation failed!\n\n" 2
  fi
}

do_sig () {
  notify_n "[KO] Cactus: Kubernetes installation failed by signal!\n\n" 2 
}

export TERM=xterm

# BEGIN of variables to customize
#
CI_DEBUG=${CI_DEBUG:-0}; [[ "${CI_DEBUG}" =~ (false|0) ]] || set -x
REPO_ROOT_PATH=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")
DEPLOY_DIR=$(cd "${REPO_ROOT_PATH}/deploy"; pwd)
TEMPLATE_DIR=${DEPLOY_DIR}/templates
CONF_DIR="${REPO_ROOT_PATH}/config"
STORAGE_DIR=/var/cactus
PREFIX=cactus
TMP_DIR=/tmp/cactus_${PREFIX}
CPU_PASS_THROUGH=${CPU_PASS_THROUGH:-1}
ONSITE=${ONSITE:-0}
LEVEL=vms


##############################################################################
# BEGIN of main
#
while getopts "p:s:P:l:rh" OPTION
do
  case $OPTION in
    p) TARGET_POD=${OPTARG} ;;
    s) SCENARIO=${OPTARG} ;;
    P) PREFIX=${OPTARG}; TMP_DIR=/tmp/cactus_${PREFIX} ;;
    l) LEVEL=${OPTARG} ;;
    r) ONSITE+=1 ;;
    h) usage; exit 0 ;;
    *) notify_e "[ERROR] Arguments not according to new argument style\n" ;;
  esac
done

if [[ "$(sudo whoami)" != 'root' ]]; then
  notify_e "[ERROR] This script requires sudo rights!"
  exit 1
fi


mkdir -p ${STORAGE_DIR}
mkdir -p ${TMP_DIR}

source "${DEPLOY_DIR}/globals.sh"
source "${DEPLOY_DIR}/lib.sh"
source "${DEPLOY_DIR}/vms.sh"
source "${DEPLOY_DIR}/k8s.sh"

# Enable the automatic exit trap
trap do_exit EXIT
trap do_sig SIGINT SIGTERM

pushd "${DEPLOY_DIR}" > /dev/null

if ! virsh list >/dev/null 2>&1; then
  notify_e "[ERROR] This script requires hypervisor access!"
fi

# Infra setup
parse_idf

update_bridges

parse_pdf

parse_scenario

cleanup_vms

cleanup_networks

[[ ${LEVEL} =~ sto|dib ]] && cleanup_sto

[[ ${LEVEL} =~ dib ]] && cleanup_dib

generate_ssh_key

build_images

prepare_networks

prepare_vms

create_networks

create_vms "${CPU_PASS_THROUGH}"

update_network admin

update_network mgmt

start_vms

check_connection

deploy_master

deploy_minion

deploy_cni

wait_cluster_ready

deploy_objects

deploy_helm
