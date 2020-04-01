FROM centos:7
MAINTAINER serena.feng.711@gmail.com
RUN yum update -y \
 && yum install -y epel-release squashfs-tools \
 && yum install -y git python-pip which qemu-img sudo e2fsprogs \
 && yum install -y iproute iproute-doc vim \
 && yum clean all
RUN pip install -U pip
RUN pip install -U 'setuptools<45.0.0' wheel
RUN pip install git+https://github.com/openstack/diskimage-builder.git

WORKDIR /work
ADD repos repos/
ADD elements elements/
ADD create_image.sh ./
RUN chmod +x create_image.sh

CMD ["/bin/bash"]

