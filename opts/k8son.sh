# !/bin/bash

set -e

onto=${1}

[[ ${onto} == "" ]] && {
  workon=$(readlink -f ~/.kube)
  echo "k8s is working on cluster [${workon##*.}]"
  exit 0
}

rm -fr ~/.kube || true
rm -fr ~/.helm || true
ln -s ~/.kube.${onto} ~/.kube
ln -s ~/.helm.${onto} ~/.helm

