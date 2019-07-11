# !/bin/bash

set -e

dir=$(dirname ${0})
origin=$(cat ${dir}/k8s.lock)
onto=${1}

[[ ${onto} == "" ]] && {
  echo "${origin}"
  exit 0
}

[[ ${origin} == ${onto} ]] && {
  echo "we are working on ${onto} cluster"
  exit 0
}

echo "backup ${origin} cluster"
[[ -d ~/.kube.${origin} ]] && rm -fr ~/.kube.${origin} || true
[[ -d ~/.helm.${origin} ]] && rm -fr ~/.helm.${origin} || true
[[ -d ~/.kube ]] && mv ~/.kube ~/.kube.${origin} || true
[[ -d ~/.helm ]] && mv ~/.helm ~/.helm.${origin} || true

[[ -n ${onto} ]] && {
  [[ ! -d ~/.kube.${onto} ]] && {
    echo "cluster ${onto} not exist"
    exit 1
  }
  echo "switch to ${onto} cluster"
  cp -fr ~/.kube.${onto} ~/.kube || true
  cp -fr ~/.helm.${onto} ~/.helm || true
  echo "${onto}" > ${dir}/k8s.lock
} || true
