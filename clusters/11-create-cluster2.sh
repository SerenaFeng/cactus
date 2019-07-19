#! /bin/bash

CLUSTER1=istio
CLUSTER2=istio2
SCENARIO=istio-remote
C1_KUBECONF=~/.kube.${CLUSTER1}/config
C2_KUBECONF=~/.kube.${CLUSTER2}/config

KCTL1="kubectl -n istio-system --kubeconfig ${C1_KUBECONF}"
KCTL2="kubectl -n istio-system --kubeconfig ${C2_KUBECONF}"

# get istio pod ips
export PILOT_POD_IP=$(${KCTL1} get pod -l istio=pilot -o jsonpath='{.items[0].status.podIP}')
export POLICY_POD_IP=$(${KCTL1} get pod -l istio-mixer-type=policy -o jsonpath='{.items[0].status.podIP}')
export TELEMETRY_POD_IP=$(${KCTL1} get pod -l istio-mixer-type=telemetry -o jsonpath='{.items[0].status.podIP}')

echo "PILOT_POD_IP: ${PILOT_POD_IP}"
echo "POLICY_POD_IP: ${POLICY_POD_IP}"
echo "TELEMETRY_POD_IP: ${TELEMETRY_POD_IP}"

template=config/scenario/${SCENARIO}.yaml.template
[[ -f ${template} ]] && {
  eval "cat <<-EOF
$(<"${template}")
EOF" 2>/dev/null > config/scenario/${SCENARIO}.yaml
}

# deploy istio-remote on the 2nd cluster
make install s=${SCENARIO} p=istio2 P=${CLUSTER2} 2>&1 | tee ${CLUSTER2}.log
