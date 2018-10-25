#!/bin/bash

USAGE="Supported Commands:\n
  sys:   under kube-system namespace \n
  istio: under istio-system namespace \n
  all:   under all namespaces \n
  apply: kubectl apply -f \n
  del:   kubectl delete -f \n
  get:   kubectl get \n
  proxy: kubectl proxy --accept-hosts='^*$' --address='10.62.105.17'\n
  top:   kubectl -n kube-system top \n
  des|describe:   kubectl describe 
"

if [ "$#" == "0" ]; then
  echo -e $USAGE
  exit 1
fi

OPTIONS=
ns=$1

case $ns in
  sys)   OPTIONS="$OPTIONS -n kube-system"; shift ;;
  istio) OPTIONS="$OPTIONS -n istio-system"; shift ;;
  all)   OPTIONS="$OPTIONS --all-namespaces"; shift ;;
esac

cmd=$1
shift

case $cmd in
  apply) kubectl apply -f $@ ;;
  del)   kubectl delete -f $@ ;;
  get)   kubectl get $@ $OPTIONS;;
  proxy) kubectl proxy --accept-hosts='^*$' --address='10.62.105.17' ;;
  top)   kubectl top $@ $OPTIONS;;
  des|describe)   kubectl describe $@ $OPTIONS;;
esac
