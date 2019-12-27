#!/bin/bash
# shortcut for docker

USAGE="Supported Commands:\n
  ex: bash ~/scripts/d-exec.sh \$container \$cmd\n
  rm:   docker rm -f\n
  rms:  d find $@ | xargs docker rm -f\n
  ims:  docker images\n
  rmi:  docker rmi\n
  rmis: docker images | grep $@ | xargs docker rmi\n
  ps:   docker ps\n
  psa:  docker ps -a\n
  find: docker ps -a | grep
"

if [ "$#" == "0" ]; then
  echo -e $USAGE
  exit 1
fi

cmd=$1
shift

case $cmd in
  ex) 
    bash ~/scripts/d-exec.sh $@ ;;
  rm) 
    docker rm -f $@ ;;
  rms)
    docker ps -a | grep $@ | grep -v grep | awk '{print $1}' | xargs -I {} docker rm -f {} &>/dev/null ;;
  ims)
    docker images ;;
  rmi)
    docker rmi $@ ;;
  rmis)
    for item in "$@"; do
      echo "start to clean $item"
      docker images | grep $item | grep -v grep | awk '{print $3}' | xargs -I {} docker rmi {} #&>/dev/null
    done
    ;;
  ps)
    docker ps $@;;
  psa)
    docker ps -a ;;
  find)
    docker ps -a | grep $@ ;;
  *)
    docker $cmd $@ ;;
esac

