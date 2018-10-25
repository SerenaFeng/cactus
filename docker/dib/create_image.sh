
#!/bin/sh

cd /imagedata

K8S_TMP=/tmp/k8s
K8S_YUM_REPO=/tmp/k8s/k8s.repo
K8S_PUBKEY=/imagedata/cactus.rsa.pub

[[ -d $K8S_TMP ]] || mkdir -p $K8S_TMP

[[ -f $K8S_YUM_REPO ]] || {
    cat > $K8S_YUM_REPO << EOF
[kubernetes]
name=Kubernetes
baseurl=http://yum.kubernetes.io/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
}

[[ -f $K8S_PUBKEY ]] || ssh-keygen -q -f ${K8S_PUBKEY%.*} -N ""

function create_k8sm_centos7_image {
    echo "Begin to build k8sm image"
    image_name=${1:-k8sm-centos7.qcow2}
    image_format=${2:-qcow2}

    ELEMENTS_PATH=/elements \
    DIB_YUM_REPO_CONF=$K8S_YUM_REPO \
    DIB_DEV_USER_USERNAME=cactus \
    DIB_DEV_USER_PASSWORD=cactus \
    DIB_DEV_USER_PWDLESS_SUDO=true \
    DIB_DEV_USER_AUTHORIZED_KEYS=$K8S_PUBKEY \
    disk-image-create centos7 vm dhcp-all-interfaces \
    cloud-init-nocloud devuser install-static cactus-static \
    -p kubelet,kubeadm,kubectl,docker,vim \
    -o ${image_name} -t ${image_format}

}

function create_node_centos7_image {
    echo "Begin to build node image"
    image_name=${1:-node_centos7.qcow2}
    image_format=${2:-qcow2}

    ELEMENTS_PATH=/elements \
    DIB_YUM_REPO_CONF=$K8S_YUM_REPO \
    DIB_DEV_USER_USERNAME=cactus \
    DIB_DEV_USER_PASSWORD=cactus \
    DIB_DEV_USER_PWDLESS_SUDO=true \
    DIB_DEV_USER_AUTHORIZED_KEYS=$K8S_PUBKEY \
    disk-image-create centos7 vm dhcp-all-interfaces \
    cloud-init-nocloud devuser install-static cactus-static \
    -p kubelet,docker,vim\
    -o ${image_name} -t ${image_format}
}

#for image_item in $( set | awk '{FS="="}  /^VM_BASE_IMAGE/ {print $2}' ); do
for image_item in k8s/k8sm.qcow2; do
    echo "Image [${image_item}] will be created...."

    [[ -f ${image_item} ]] && {
       echo "Image [${image_item}] already exists, skip it."
       continue
    }

    image_name=${image_item##*/}
    image_format=${image_item##*.}
    [[ ${image_item} =~ "/" ]] && dir_name=${image_item%/*} || dir_name=""

    [[ ${image_item} =~ "k8sm" ]] && {
        [[ -n ${dir_name} ]] && {
            mkdir -p ${dir_name}
            pushd ${dir_name}
            create_k8sm_centos7_image ${image_name} ${image_format} || true
            popd
        } || {
            create_k8sm_centos7_image ${image_name} ${image_format} || true
        }
        echo "Image [${image_item}] create successfully."
        continue
    }
    [[ ${image_item} =~ "node" ]] && {

        [[ -n ${dir_name} ]] && {
            mkdir -p ${dir_name}
            pushd ${dir_name}
            create_node_centos7_image ${image_name} ${image_format} || true
            popd
        } || {
            create_node_centos7_image ${image_name} ${image_format} || true
        }
        echo "Image [${image_item}] create successfully."
        continue
    }
done
