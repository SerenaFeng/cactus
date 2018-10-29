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

  make install DEBUG=<true|false> where=<vms|local> pod=<pod-name> scenario=<scenario-name>

*DEBUG*: whether to track bash execution commands or not
*where*: where to deploy the Kubernetes, only vms is supported
*pod*: pod name, will substitute "xxx" in idf-xxx.yaml & pdf-xxx.yaml
*scenario*: scenario name, will substitute "scenario" in scenario.yaml

