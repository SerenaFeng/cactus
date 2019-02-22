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

define INSTALL_HELP
# Deploy k8s locally or on vms.
#
# Args:
#   help: $(HELP)
#   where: local or vms
#   s: scenario, defined under config/scenario, default by istio
#   p: pod name, definded under config/labs, default by pod1
#   P: prefix for node name, default by cactus
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
	sudo CI_DEBUG=$(debug) bash deploy/deploy.sh -s $(s) -p $(p) -P $(P)
endif

.phone: stop
stop: 
	bash ./stop.sh


define APPLY_HELP
# Apply objects on k8s.
#
# Args:
#   help: $(HELP)
#   what: Object to apply, supported objects: $(OBJS)
#
# Example:
#   make apply what=metrics-server
#   
endef

.phone: apply
ifeq ($(help), y)
apply:
	@echo "$$APPLY_HELP"
else
apply:
	kubectl apply -f $(CONFDIR)/$(what)
endif


define REMOVE_HELP
# Remove objects.
#
# Args:
#   help: $(HELP)
#   what: Object to delete, supported objects: $(OBJS)
#   
# Example:
#   make delete what=metrics-server
#   
endef
.phone: delete
ifeq ($(help), y)
delete:
	@echo "$$REMOVE_HELP"
else
delete:
	kubectl delete -f $(CONFDIR)/$(what)
endif

