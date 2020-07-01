#!/bin/bash

###############################################################################
#
#                             deploy-cicd-infra.sh
#
# This is the deployment script for required CI/CD infrastructure.
#
###############################################################################
set -eo pipefail

# Make sure common.sh is here.
SCRIPT_ROOT=$(dirname $(readlink -f "$0"))
. "${SCRIPT_ROOT}/common.sh" || { echo "Unable to load common.sh"; exit 1; }

# Config

###############################################################################
# ===================== Installing K8S dependencies
###############################################################################
info "Configuring Google dependencies and Kubernetes secrets..."

# ===================== Ensure logged in to GCP
${SCRIPT_ROOT}/login.sh

# ===================== Deploy K8s cluster
gcloud beta container \
    --project "bitcoin-global-infra" clusters create "eu-master-cluster" \
    --zone "europe-west1-b" \
    --no-enable-basic-auth \
    --cluster-version "1.16.9-gke.6" \
    --machine-type "custom-2-4096" \
    --image-type "UBUNTU_CONTAINERD" \
    --disk-type "pd-standard" \
    --disk-size "100" \
    --metadata disable-legacy-endpoints=true \
    --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
    --preemptible \
    --num-nodes "1" \
    --enable-stackdriver-kubernetes \
    --enable-ip-alias \
    --network "projects/bitcoin-global-infra/global/networks/default" \
    --subnetwork "projects/bitcoin-global-infra/regions/europe-west1/subnetworks/default" \
    --default-max-pods-per-node "110" \
    --enable-autoscaling \
    --min-nodes "0" \
    --max-nodes "1" \
    --no-enable-master-authorized-networks \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing \
    --no-enable-autoupgrade \
    --enable-autorepair \
    --max-surge-upgrade 1 \
    --max-unavailable-upgrade 0 \
    --enable-shielded-nodes \
    --shielded-secure-boot
