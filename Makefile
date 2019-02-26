# It's necessary to set this because some environments don't link sh -> bash.
SHELL := /bin/bash

# Constants used throughout.
# We don't need make's built-in rules.
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

.EXPORT_ALL_VARIABLES:
CONFDIR ?= ./kube-config
OBJS := calico dashboard example flannel heapster hostpath metrics-server
HELP := =y print this help information
debug ?= false
s ?= istio  # scenario
where ?= vms
p ?= pod1 # lowercase p, pod name
P ?= cactus # uppercase P, prefix for node name
l ?= vms

define INSTALL_HELP
# Deploy k8s locally or on vms.
#
# Args:
#   help: $(HELP)
#   where: local or vms
#   s: scenario, defined under config/scenario, default by istio
#   p: pod name, definded under config/labs, default by pod1
#   P: prefix for node name, default by cactus
#   l: cleanup level, dib=all resources, sto=all except dib image, vms=only vms and networks, default by vms
# Example:
#   make install where=vms
#   
endef
.phone: install
ifeq ($(help), y)
install:
	@echo "$$INSTALL_HELP"
else ifeq ($(where), local)
install:
	bash k8s/k8sm.sh
else
install:
	sudo CI_DEBUG=$(debug) bash deploy/deploy.sh -s $(s) -p $(p) -P $(P) -l $(l)
endif

define STOP_HELP
# STOP k8s deployment.
#
# Args:
#   help: $(HELP)
# Example:
#   make stop
#
endef
.phone: stop
ifeq ($(help), y)
stop:
	@echo "$$STOP_HELP"
else
stop: 
	bash ./stop.sh
endif

define CLEAN_HELP
# Clean k8s deployment envs.
#
# Args:
#   help: $(HELP)
#   s: scenario, defined under config/scenario, default by istio
#   p: pod name, definded under config/labs, default by pod1
#   l: cleanup level, dib=all resources, sto=all except dib image, vms=only vms and networks, default by vms
#   P: uppercase, prefix for node name, default by cactus
# Example:
#   make clean s=istio P=cactus c=dib
#
endef
.phone: clean
ifeq ($(help), y)
clean:
	@echo "$$CLEAN_HELP"
else
clean:
	sudo CI_DEBUG=$(debug) bash deploy/clean.sh -P $(P) -s $(s) -l $(l) -p $(p)
endif

define APPLY_HELP
# Apply objects on k8s.
#
# Args:
#   help: $(HELP)
#   o: Object to apply, supported objects: $(OBJS)
#
# Example:
#   make apply o=metrics-server
#   
endef

.phone: apply
ifeq ($(help), y)
apply:
	@echo "$$APPLY_HELP"
else
apply:
	kubectl apply -f $(CONFDIR)/$(o)
endif


define REMOVE_HELP
# Remove objects.
#
# Args:
#   help: $(HELP)
#   o: Object to delete, supported objects: $(OBJS)
#   
# Example:
#   make delete o=metrics-server
#   
endef
.phone: delete
ifeq ($(help), y)
delete:
	@echo "$$REMOVE_HELP"
else
delete:
	kubectl delete -f $(CONFDIR)/$(o)
endif

