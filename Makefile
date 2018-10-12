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
.phone: deploy

define DEPLOY_HELP
# Deploy objects.
#
# Args:
#   help: $(HELP)
#   what: Object to deploy, supported objects: $(OBJS)
#   
# Example:
#   make deploy what=metrics-server
#   
endef

ifeq ($(help), y)
deploy:
	@echo "$$DEPLOY_HELP"
else
deploy:
	kubectl apply -f $(CONFDIR)/$(what)
endif

.phone: remove

define REMOVE_HELP
# Remove objects.
#
# Args:
#   help: $(HELP)
#   what: Object to remove, supported objects: $(OBJS)
#   
# Example:
#   make remove what=metrics-server
#   
endef
ifeq ($(help), y)
remove:
	@echo "$$REMOVE_HELP"
else
remove:
	kubectl delete -f $(CONFDIR)/$(what)
endif

