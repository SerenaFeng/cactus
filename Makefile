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
CI_DEBUG := False
SCENARIO := calico-noha.yaml

ifeq ($(DEBUG), y)
    CI_DEBUG = True
endif

define INSTALL_HELP
# Deploy k8s locally or on vms.
#
# Args:
#   help: $(HELP)
#   where: local or vms
#   scenario: deploy states, such as calico-defaults-noha
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
    ifdef scenario
        SCENARIO=$(scenario)
    endif
	sudo CI_DEBUG=$(CI_DEBUG) bash deploy/deploy.sh -s $(SCENARIO)
endif

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

