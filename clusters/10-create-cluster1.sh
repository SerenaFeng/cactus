#! /binn/bash

CLUSTER1=istio
C1_KUBECONF=~/.kube.${CLUSTER1}/config
KCTL1=kubectl -n istio-system --kubeconfig ${C1_KUBECONF}

# deploy the 1st cluster with integral istio
make install s=istio p=istio P=${CLUSTER1} 2>&1 | tee ${CLUSTER1}.log


# deploy the 2nd cluster with remote istio
export PILOT_POD_IP=$(${KCTL1} get pod -l istio=pilot -o jsonpath='{.items[0].status.podIP}')
export POLICY_POD_IP=$(${KCTL1} get pod -l istio-mixer-type=policy -o jsonpath='{.items[0].status.podIP}')
export TELEMETRY_POD_IP=$(${KCTL1} system get pod -l istio-mixer-type=telemetry -o jsonpath='{.items[0].status.podIP}')

echo "PILOT_POD_IP: ${PILOT_POD_IP}"
echo "POLICY_POD_IP: ${POLICY_POD_IP}"
echo "TELEMETRY_POD_IP: ${TELEMETRY_POD_IP}"

