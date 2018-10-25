#!/bin/bash -e
##############################################################################
# Copyright (c) 2017 Ericsson AB, Mirantis Inc., Enea AB and others.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Global variables
export CI_DEBUG=${CI_DEBUG:-0}; [[ "${CI_DEBUG}" =~ (false|0) ]] || set -x
export SSH_KEY=${SSH_KEY:-"${STORAGE_DIR}/cactus.rsa"}

# Derivated from above global vars
export SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${SSH_KEY}"

# same as `notify_i` + trailing '\n';
function notify() {
    local msg=${1}; shift
    notify_i "${msg}\n" "$@"
}

# Inline (no newline added) colored output notification wrapper
function notify_i() {
    tput setaf "${2:-1}" || true
    echo -en "${1:-"[WARN] Unsupported opt arg: $3\\n"}"
    tput sgr0
}

# same as `notify` + extra '\n' before and after;
function notify_n() {
    local msg=${1}; shift
    notify_i "\n${msg}\n\n" "$@"
}

# same as `notify` + stderr output + exit;
function notify_e() {
    local msg=${1}; shift
    notify_i "\n${msg}\n\n" "$@" 1>&2
    exit 1
}

# Display slogan
function print_slogan() {
(
  set +x
  for i in {1..120}; do echo -n "="; done;echo ""
)
}

#
# END of colored notification wrapper
##############################################################################
