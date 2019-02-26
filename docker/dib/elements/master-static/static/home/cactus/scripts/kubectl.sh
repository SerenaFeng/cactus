#!/bin/bash

USAGE="
Supported Commands:
  a|apply:      kubectl apply -f
  c|create:     kubectl create
  d|del|delete: kubectl delete -f
  g|get:        kubectl get
  l|label:      kubectl label
  p|proxy:      kubectl proxy --accept-hosts='^*$' --address='10.62.105.17'
  t|top:        kubectl -n kube-system top
  des|describe: kubectl describe

Support namespace abbreviations:
  sys:          under kube-system namespace
  istio:        under istio-system namespace
  all:          under all namespaces

Usage:
  k [ns_abbr] [cmd] [options]
or
  k [cmd] [options]
"

if [ "$#" == "0" ]; then
  echo -e "$USAGE"
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
  a|apply) kubectl apply -f $@ $OPTIONS ;;
  d|del|delete) 
    [[ $# -gt 1 ]] && [[ ! $2 =~ ^-.* ]] && {
      kubectl delete $@ $OPTIONS || true
    } || {
      kubectl delete -f $@ $OPTIONS || true
    }
    ;;
  c|create)   kubectl create $@ $OPTIONS ;;
  e|edit)   kubectl edit $@ $OPTIONS ;;
  g|get)   kubectl get $@ $OPTIONS ;;
  l|label)   kubectl label $@ $OPTIONS ;;
  p|proxy) kubectl proxy --accept-hosts='^*$' --address='10.62.105.17' ;;
  t|top)   kubectl top $@ $OPTIONS ;;
  des|describe)   kubectl describe $@ $OPTIONS ;;
  *) kubectl $cmd $@ $OPTIONS ;;
esac
