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
d ?= False
s ?= istio  # scenario
w ?= vms
p ?= pod1 # lowercase p, pod name
P ?= cactus # uppercase P, prefix for node name
l ?= nw

define INSTALL_HELP
# Deploy k8s locally or on vms.
#
# Args:
#   h: $(HELP)
#   w: local or vms
#   s: scenario, defined under config/scenario, default by istio
#   p: pod name, definded under config/labs, default by pod1
#   P: prefix for node name, default by cactus
#   l: cleanup level, dib=all resources, sto=all except dib image, nw=network and vms, vms=only vms, default by nw
# Example:
#   make install w=vms
#   
endef
.phone: install
ifeq ($(h), y)
install:
	@echo "$$INSTALL_HELP"
else ifeq ($(w), local)
install:
	bash k8s/k8sm.sh
else
install:
	sudo CI_DEBUG=$(d) bash deploy/deploy.sh -s $(s) -p $(p) -P $(P) -l $(l) 2>&1 | tee $(P).log
endif

define STOP_HELP
# STOP k8s deployment.
#
# Args:
#   h: $(HELP)
# Example:
#   make stop
#
endef
.phone: stop
ifeq ($(h), y)
stop:
	@echo "$$STOP_HELP"
else
stop: 
	bash opts/stop.sh
endif

define CLEAN_HELP
# Clean k8s deployment envs.
#
# Args:
#   h: $(HELP)
#   l: cleanup level, dib=all resources, sto=all except dib image, nw=network and vms, vms=only vms, default by nw
#   P: uppercase, prefix for node name, default by cactus
# Example:
#   make clean P=cactus c=dib
#
endef
.phone: clean
ifeq ($(h), y)
clean:
	@echo "$$CLEAN_HELP"
else
clean:
	sudo CI_DEBUG=$(debug) bash deploy/clean.sh -P $(P) -l $(l) 
endif

define APPLY_HELP
# Apply objects on k8s.
#
# Args:
#   h: $(HELP)
#   o: Object to apply, supported objects: $(OBJS)
#
# Example:
#   make apply o=metrics-server
#   
endef

.phone: apply
ifeq ($(h), y)
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
#   h: $(HELP)
#   o: Object to delete, supported objects: $(OBJS)
#   
# Example:
#   make delete o=metrics-server
#   
endef
.phone: delete
ifeq ($(h), y)
delete:
	@echo "$$REMOVE_HELP"
else
delete:
	kubectl delete -f $(CONFDIR)/$(o)
endif

define do_deploy
	sudo CI_DEBUG=$(d) bash deploy/deploy.sh \
		-P $(1) \
		-s $(2) \
		-p $(3) \
		$(if $(4), -l $(4), -l nw) \
		$(if $(5), -a $(5)) 2>&1 | tee $(1).log
endef

helm:
	$(call do_deploy, helm, helm, pod7)
basic:
	$(call do_deploy, basic, basic, pod11)
rmain:
	$(call do_deploy, rmain, basic, pod1)
rremote:
	$(call do_deploy, rremote, basic, pod2)
xmain:
	$(call do_deploy, xmain, xmain, pod3)
xremote:
	$(call do_deploy, xremote, xremote, pod4)
smain:
	$(call do_deploy, smain, smain, pod5.1)
sremote:
	$(call do_deploy, sremote, sremote, pod5.2, vms, smain)
