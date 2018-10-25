#!/bin/bash

USAGE="Supported Commands:\n
  in:   docker exec -ti \$@ bash\n
  exec: bash ~/scripts/d-exec.sh \$container \$cmd\n
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
  in) 
    docker exec -ti $@ bash ;;
  exec) 
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
    docker images | grep $@ | grep -v grep | awk '{print $3}' | xargs -I {} docker rmi {} &>/dev/null ;;
  ps)
    docker ps ;;
  psa)
    docker ps -a ;;
  find)
    docker ps -a | grep $@
esac

