#!/bin/bash
# shortcut for kubectl

USAGE="
Supported Commands:
  a*:      kubectl apply -f
  c*:      kubectl create
  d*:      kubectl delete -f
  e*:      kubectl edit
  g*:      kubectl get
  lo*|log: kubectl logs
  l*:      kubectl label
  pf:      kubectl port-forward
  p*:      kubectl proxy --accept-hosts='^*$' --address='10.62.105.17'
  t*:      kubectl -n kube-system top
  des*:    kubectl describe

Support namespace abbreviations:
  sys:          under kube-system namespace
  istio:        under istio-system namespace
  jenkins:      under jenkins namespace
  we:           under webhook namespace
  twe:          under twe namespace
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
  sys)     OPTIONS="$OPTIONS -n kube-system"; shift ;;
  istio)   OPTIONS="$OPTIONS -n istio-system"; shift ;;
  jenkins) OPTIONS="$OPTIONS -n jenkins"; shift ;;
  we)      OPTIONS="$OPTIONS -n webhook"; shift ;;
  twe)     OPTIONS="$OPTIONS -n twe"; shift ;;
  all)     OPTIONS="$OPTIONS --all-namespaces"; shift ;;
esac

cmd=$1
shift

#shopt -s extglob
case $cmd in
  a*)       kubectl apply -f $@ $OPTIONS ;;
  des*)     kubectl describe $@ $OPTIONS ;;
  pf)       kubectl port-forward $@ $OPTIONS ;;
  d*) 
    [[ $# -gt 1 ]] && [[ ! $2 =~ ^-.* ]] && {
      kubectl delete $@ $OPTIONS || true
    } || {
      kubectl delete -f $@ $OPTIONS || true
    }
    ;;
  c*)       kubectl create $@ $OPTIONS ;;
  ex*)      kubectl exec $@ $OPTIONS ;;
  e*)       kubectl edit $@ $OPTIONS ;;
  g*)       kubectl get $@ $OPTIONS ;;
  lo*|lg)   kubectl logs $@ $OPTIONS ;;
  l*)       kubectl label $@ $OPTIONS ;;
  p*)       kubectl proxy --accept-hosts='^*$' --address='10.62.105.17' ;;
  t*)       kubectl top $@ $OPTIONS ;;
  *)        kubectl $cmd $@ $OPTIONS ;;
esac
