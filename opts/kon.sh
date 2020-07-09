# !/bin/bash

onto=${1}

if [[ ${onto} == "" ]]; then
  [[ ${K8SON} == "" ]] && {
    workon=$(readlink -f ~/.kube)
  } || {
    workon=${K8SON}
  }
  echo "${workon##*.}"
elif [[ ${onto} == "ls" ]]; then
  dirs=$(ls -d ~/.kube.*)
  scenaries=""
  for dir in ${dirs}; do
    scenary=${dir##*.}
    virsh list | grep ${scenary} > /dev/null
    [[ 0 == $? ]] && scenaries="${scenaries} ${scenary}"
  done
  echo ${scenaries}
else
  [[ ! -d ~/.kube.${onto} ]] && {
    echo "cluster ${onto} not exist"
    return
  }

  export K8SON=${onto}
  sudo rm -fr ~/.kube || true
  ln -s ~/.kube.${onto} ~/.kube

  [[ -d ~/.helmctl.${onto} ]] && {
    sudo rm -fr ~/.helmctl || true
    ln -s ~/.helmctl.${onto} ~/.helmctl
  }

  [[ -d ~/.istioctl.${onto} ]] && {
    sudo rm -fr ~/.istioctl || true
    ln -s ~/.istioctl.${onto} ~/.istioctl
  }
fi

