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
    -n=*|--name=*)         VM_NAME="${i#*=}" 
    shift ;;
    -z=*|--zone=*)         VM_ZONE="${i#*=}"
    shift ;;
    --script-path=*)       VM_SCRIPT="${i#*=}"
    shift ;;
    --size=*)              VM_SIZE="${i#*=}"
    shift ;;
    --disk-size=*)         DISK_SIZE="${i#*=}"
    shift ;;
    --disk-type=*)         DISK_TYPE="${i#*=}"
    shift ;;
    --tags=*)              TAGS="${i#*=}"
    shift ;;
    --preemptible)         VM_PREEMPTIBLE="--preemptible"
    shift ;;
    --static-ip)           STATIC_IP="true"
    ;;
    *) error "Unknown parameter passed: $i"; exit 1 ;;
esac
done

# Make sure required params are provided
kill_if_empty "--name" $VM_NAME
kill_if_empty "--zone" $VM_ZONE

VM_SIZE=${VM_SIZE:-g1-small}
DISK_SIZE=${DISK_SIZE:-10GB}
DISK_TYPE=${DISK_TYPE:-pd-standard}
VM_PREEMPTIBLE=${VM_PREEMPTIBLE:-}
ADDITIONAL_ARGS=""

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
${SCRIPT_ROOT}/login.sh

# ===================== Create or start isntance
VM_INSTANCE=$(gcloud compute instances list --filter="name:($VM_NAME)" --format yaml)

if [ -z "$VM_INSTANCE" ]; then

    if [ ! -z "$STATIC_IP" ]; then
        VM_REGION=${VM_ZONE:0:-2}
        ADDRESS_NAME=$VM_NAME-address
        LIST_ADDRESSES=$(gcloud compute addresses list --uri)
        if grep -q "$ADDRESS_NAME" <<<"$LIST_ADDRESSES"; then
            info "Static IP address already exists, skipping..."
        else
            info "Creating static IP address (region: $VM_REGION)..."
            gcloud compute addresses create $VM_NAME-address \
                --network-tier=STANDARD --region=$VM_REGION
        fi
        EXTERNAL_IP=$(gcloud compute addresses describe $ADDRESS_NAME --region $VM_REGION  --format json | jq '.address' | tr -d '"')
        ADDITIONAL_ARGS="$ADDITIONAL_ARGS --address=$EXTERNAL_IP"
    fi

    info "Creating VM instance ($VM_NAME) (zone: $VM_ZONE)..."
    gcloud beta compute instances create $VM_NAME \
        $ADDITIONAL_ARGS \
        --zone=$VM_ZONE \
        --machine-type=$VM_SIZE \
        --subnet=default \
        --network-tier=STANDARD \
        --metadata=ssh-keys="${SSH_USER}:${SSH_PUBLIC_KEY}" \
        $VM_SCRIPT_TAG \
        --no-restart-on-failure \
        --maintenance-policy=TERMINATE \
        $VM_PREEMPTIBLE \
        --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
        --image=ubuntu-1804-bionic-v20200626 \
        --image-project=ubuntu-os-cloud \
        --boot-disk-size=$DISK_SIZE \
        --boot-disk-type=$DISK_TYPE \
        --boot-disk-device-name=$VM_NAME \
        --no-shielded-secure-boot \
        --shielded-vtpm \
        --shielded-integrity-monitoring \
        --reservation-affinity=any \
        --tags=${TAGS:-automated-script}
else
    warn "VM instance ($VM_NAME) (zone: $VM_ZONE) already exists, powering on..."
    gcloud compute instances start $VM_NAME --zone=$VM_ZONE
fi
