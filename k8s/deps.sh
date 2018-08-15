#!/usr/bin/env bash
function install-docker() {
    $APTGET update
    $APTGET install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $APTKEY add -
    $ADDAPT "deb https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $(lsb_release -cs) stable"
    $APTGET update && $APTGET install -y docker-ce=$(apt-cache madison docker-ce | grep 17.03 | head -1 | awk '{print $3}')

}

function install-kubetools() {
    $APTGET update && $APTGET install -y apt-transport-https curl
    curl -s https://packages.cloud.google.com/apt/doc/$APTKEY.gpg | $APTKEY add -
    cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
    $APTGET update
    $APTGET install -y kubelet kubeadm kubectl
    $APTMARK hold kubelet kubeadm kubectl
}
