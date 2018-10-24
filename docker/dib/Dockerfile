FROM centos:7
MAINTAINER serena.feng.711@gmail.com
RUN yum update -y \
 && yum install -y epel-release  \
 && yum install -y git python-pip which qemu-img sudo e2fsprogs \
 && yum install -y iproute iproute-doc vim \
 && yum clean all \
 && pip install -U git+https://github.com/openstack/diskimage-builder.git
ADD elements /elements
ADD create_image.sh /create_image.sh
RUN chmod +x /create_image.sh

CMD ["/bin/bash"]
