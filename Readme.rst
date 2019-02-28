cactus                                                                                              
########                                                                                            
                                                                                                    
A tool to deploy a local testing Kubernetes on VMS leveraging libvirt. There will be 1+n VMS
deployed automatically, 1 master, and n minions based on the definition on pdf file. The OS of VMS
is specified as centos7.

Configure files
----------------

**idf-xxx.yaml**

The network relevant configurations, admin and mgmt must be specified, and the last figure shouldn't
be "2" since it is the figure of admin and mgmt. Put under config/lab.

**pdf-xxx.yaml**

The specifications of VMS. Note that node_id must start from "2", because it is used as the last
figure of admin and mgmt IP address. Put under config/lab

**scenario.yaml**

This file determines what kind of Kubernetes will be deployed. Currently, CRI is fixed to docker,
and CSI is not supported. Put under config/scenario

Deployment
-----------

  .. code-block:: bash

  make install d=<true|false> w=<vms|local> p=<pod-name> s=<scenario-name> P=<prefix> l=<cleanup_level>

- *w*: the way to deploy the Kubernetes, only vms is supported
- *p*: pod name, defined under config/labs, substitute "xxx" in idf-xxx.yaml & pdf-xxx.yaml
- *s*: scenario name, defined under config/scenario, substitute "scenario" in scenario.yaml
- *P*: prefix of node name, joint node name with "_"
- *l*: cleanup(reinstall) level, vms/sto/dib, vms means cleanup vms and networks before deploy k8s cluster; level sto besides what vms level does, also removes disk images; while dib will cleanup all the resources include dib image, it is a wholy new fresh installation. default by vms
- *d*: whether to track bash execution commands or not, True/False, Default by False
- *h*: print help information

