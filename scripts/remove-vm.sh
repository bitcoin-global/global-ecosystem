#!/bin/bash

###############################################################################
#
#                             add-vm.sh
#
# This script provisions or starts a VM depending on status on Google Cloud.
#
###############################################################################
set -eo pipefail

# Make sure common.sh is here.
SCRIPT_ROOT=$(dirname $(readlink -f "$0"))
. "${SCRIPT_ROOT}/common.sh" || { echo "Unable to load common.sh"; exit 1; }

# Ensure to run as CLI
for i in "$@"
do
case $i in
    -n=*|--name=*)      VM_NAME="${i#*=}" 
    shift ;;
    -d=*|--zone=*)      VM_ZONE="${i#*=}"
    shift ;;
    --destroy)          VM_DESTROY="true"
    ;;
    *) error "Unknown parameter passed: $i"; exit 1 ;;
esac
done

# Make sure required params are provided
kill_if_empty "--name" $VM_NAME
kill_if_empty "--zone" $VM_ZONE

###############################################################################
# ===================== Installing K8S dependencies
###############################################################################
info "Configuring Google Cloud..."

# ===================== Ensure logged in to GCP
./login.sh

# ===================== Create or start isntance
VM_INSTANCE=$(gcloud compute instances list --filter="name:($VM_NAME)" --format yaml)

if [ -z "$VM_INSTANCE" ]; then
    warn "VM instance ($VM_NAME) (zone: $VM_ZONE) does not exist, skipping..."
else
    if [ -z "$VM_DESTROY" ]; then
        info "Shutting down instance ($VM_NAME) (zone: $VM_ZONE)..."
        gcloud compute instances stop $VM_NAME --zone=$VM_ZONE
    else
        info "Destroying instance ($VM_NAME) (zone: $VM_ZONE)..."
        gcloud compute instances delete $VM_NAME --zone=$VM_ZONE --quiet
    fi
fi
