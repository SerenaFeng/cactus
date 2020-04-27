#!/bin/bash
# shortcut for kubectl

KCTL="kubectl"

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
  test:         under test namespace
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

[[ -n ${K8SON} ]] && KCTL="$KCTL --kubeconfig ${K8SON}/config"

OPTIONS=
ns=$1

case $ns in
  sys)     OPTIONS="$OPTIONS -n kube-system"; shift ;;
  istio)   OPTIONS="$OPTIONS -n istio-system"; shift ;;
  jenkins) OPTIONS="$OPTIONS -n jenkins"; shift ;;
  test)    OPTIONS="$OPTIONS -n test"; shift ;;
  twe)     OPTIONS="$OPTIONS -n twe"; shift ;;
  all)     OPTIONS="$OPTIONS --all-namespaces"; shift ;;
esac

cmd=$1
shift

#shopt -s extglob
case $cmd in
  a*)       ${KCTL} apply -f $@ $OPTIONS ;;
  des*)     ${KCTL} describe $@ $OPTIONS ;;
  pf)       ${KCTL} port-forward $@ $OPTIONS ;;
  d*) 
    [[ $# -gt 1 ]] && [[ ! $2 =~ ^-.* ]] && {
      ${KCTL} delete $@ $OPTIONS || true
    } || {
      ${KCTL} delete -f $@ $OPTIONS || true
    }
    ;;
  c*)       ${KCTL} create $@ $OPTIONS ;;
  ex*)      ${KCTL} exec $@ $OPTIONS ;;
  e*)       ${KCTL} edit $@ $OPTIONS ;;
  g*)       ${KCTL} get $@ $OPTIONS ;;
  lo*|lg)   ${KCTL} logs $@ $OPTIONS ;;
  l*)       ${KCTL} label $@ $OPTIONS ;;
  p*)       ${KCTL} proxy --accept-hosts='^*$' --address='10.62.105.17' ;;
  t*)       ${KCTL} top $@ $OPTIONS ;;
  *)        ${KCTL} $cmd $@ $OPTIONS ;;
esac
