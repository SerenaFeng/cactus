# !/bin/bash

onto=${1}

if [[ ${onto} == "" ]]; then
  [[ ${K8SON} == "" ]] && {
    workon=$(readlink -f ~/.kube)
  } || {
    workon=${K8SON}
  }
  echo "${workon##*.}"
else
  [[ ! -d ~/.kube.${onto} ]] && {
    echo "cluster ${onto} not exist"
    return
  }

  rm -fr ~/.kube || true
  rm -fr ~/.helm || true

  K8SON=~/.kube.${onto}
  ln -s ~/.kube.${onto} ~/.kube
  export K8SON
  [[ -d ~/.helm.${onto} ]] && {
    K8SON_HELM=~/.helm.${onto}
    ln -s ~/.helm.${onto} ~/.helm
    export K8SON_HELM
  }
fi

