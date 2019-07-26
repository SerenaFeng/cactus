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

[[ -d ~/.kube.${onto} ]] || {
  echo "cluster ${onto} not exist"
  exit 1
}

ln -s ~/.kube.${onto} ~/.kube
[[ -d ~/.helm.${onto} ]] && ln -s ~/.helm.${onto} ~/.helm

