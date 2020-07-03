#!/bin/bash

###############################################################################
#
#                             destroy-cicd.sh
#
# This is the deployment script for required CI/CD infrastructure for shared
# projects. 
# Reference: https://github.com/EngineerBetter/control-tower
#
###############################################################################
set -eo pipefail

# Make sure common.sh is here.
SCRIPT_ROOT=$(dirname $(readlink -f "$0"))
. "${SCRIPT_ROOT}/common.sh" || { echo "Unable to load common.sh"; exit 1; }

###############################################################################
# ===================== Removing K8S data
###############################################################################
info "Configuring Google dependencies and Kubernetes secrets..."

# ===================== Ensure logged in to GCP
${SCRIPT_ROOT}/login.sh --gke

# ===================== Remove Helm chart
helm delete concourse

# ----------------------------
# TODO: Delete additionally created resources