
#!/bin/sh

cd /imagedata
VERSION=${1##*v}
IMAGE=${2:-ubuntu_bionic.qcow2}
PUBKEY=/work/rsa.pub

[[ -f $PUBKEY ]] || ssh-keygen -q -f ${PUBKEY%.*} -N ""

function create_ubuntu_bionic () {
  local image=${1:-ubuntu_bionic.qcow2}
  local format=${image##*.}

  DIB_APT_SOURCES=/work/repos/apt_bionic.list \
  DIB_ADD_APT_KEYS=/work/repos/keys \
  DIB_DEV_USER_USERNAME=cactus\
  DIB_DEV_USER_PASSWORD=Cactus123! \
  DIB_DEV_USER_PWDLESS_SUDO=true \
  DIB_DEV_USER_AUTHORIZED_KEYS=${PUBKEY} \
  DIB_SHOW_IMAGE_USAGE=1 \
  DIB_SHOW_IMAGE_USAGE_FULL=0 \
  DIB_RELEASE=bionic \
  disk-image-create ubuntu vm dhcp-all-interfaces enable-serial-console \
    cloud-init-nocloud devuser apt-sources dpkg \
    -p kubectl=${VERSION}-00,kubelet=${VERSION}-00,kubeadm=${VERSION}-00,docker.io,vim \
    -o ${image} -t ${format}

}

function create_centos7 () {
  local image=${1:-centos.qcow2}
  local format=${image##*.}

  ELEMENTS_PATH=/elements \
  DIB_YUM_REPO_CONF=/work/repos/yum.repo \
  DIB_DEV_USER_USERNAME=cactus \
  DIB_DEV_USER_PASSWORD=Cactus123! \
  DIB_DEV_USER_PWDLESS_SUDO=true \
  DIB_DEV_USER_AUTHORIZED_KEYS=${PUBKEY} \
  disk-image-create centos7 vm dhcp-all-interfaces \
  cloud-init-nocloud devuser install-static common-static master-static \
  -p kubelet-${VERSION},kubeadm-${VERSION},kubectl-${VERSION},docker,vim \
  -o ${image} -t ${format}
}

#for IMAGE in $( set | awk '{FS="="}  /^VM_BASE_IMAGE/ {print $2}' ); do

echo "Image [${IMAGE}] will be created...."

limage=${1}/${IMAGE}
image_name=${IMAGE%.*}

[[ -f ${limage} ]] && {
  echo "Image [${IMAGE}] already exists, skip it."
  exit 0
}

echo "$image_name"
if [[ "$(LC_ALL=C type -t create_${image_name})" == function ]]; then
  echo "Begin to build ${limage} ... "
  eval create_${image_name} ${limage}
else
  echo "Image type [${image_name}] is not supported currently"
fi
