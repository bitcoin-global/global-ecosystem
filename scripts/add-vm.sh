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
    -n=*|--name=*)              VM_NAME="${i#*=}" 
    shift ;;
    -d=*|--zone=*)              VM_ZONE="${i#*=}"
    shift ;;
    -t=*|--script-path=*)       VM_SCRIPT="${i#*=}"
    shift ;;
    -t=*|--size=*)              VM_SIZE="${i#*=}"
    shift ;;
    -t=*|--disk-size=*)         DISK_SIZE="${i#*=}"
    shift ;;
    -t=*|--disk-type=*)         DISK_TYPE="${i#*=}"
    shift ;;
    *) error "Unknown parameter passed: $i"; exit 1 ;;
esac
done

# Make sure required params are provided
kill_if_empty "--name" $VM_NAME
kill_if_empty "--zone" $VM_ZONE

VM_SIZE=${VM_SIZE:-g1-small}
DISK_SIZE=${DISK_SIZE:-10GB}
DISK_TYPE=${DISK_TYPE:-pd-standard}

if [ -z $VM_SCRIPT ]; 
then
    VM_SCRIPT_TAG=""
else
    VM_SCRIPT_TAG="--metadata-from-file startup-script=$VM_SCRIPT"
fi

###############################################################################
# ===================== Installing K8S dependencies
###############################################################################
info "Configuring Google Cloud..."

# ===================== Ensure logged in to GCP
./login.sh

# ===================== Create or start isntance
VM_INSTANCE=$(gcloud compute instances list --filter="name:($VM_NAME)" --format yaml)

if [ -z "$VM_INSTANCE" ]; then
    info "Creating VM instance ($VM_NAME) (zone: $VM_ZONE)..."
    gcloud beta compute instances create $VM_NAME \
        --zone=$VM_ZONE \
        --machine-type=$VM_SIZE \
        --subnet=default \
        --network-tier=PREMIUM \
        --metadata=ssh-keys="${SSH_USER}:${SSH_PUBLIC_KEY}" \
        $VM_SCRIPT_TAG \
        --no-restart-on-failure \
        --maintenance-policy=TERMINATE \
        --preemptible \
        --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
        --image=ubuntu-1804-bionic-v20200610 \
        --image-project=ubuntu-os-cloud \
        --boot-disk-size=$DISK_SIZE \
        --boot-disk-type=$DISK_TYPE \
        --boot-disk-device-name=$VM_NAME \
        --no-shielded-secure-boot \
        --shielded-vtpm \
        --shielded-integrity-monitoring \
        --reservation-affinity=any \
        --tags automated-script
else
    warn "VM instance ($VM_NAME) (zone: $VM_ZONE) already exists, powering on..."
    gcloud compute instances start $VM_NAME --zone=$VM_ZONE
fi
