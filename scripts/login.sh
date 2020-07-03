#!/bin/bash

###############################################################################
#
#                             login.sh
#
# This file makes sure that you are logged in to required infrastructure
# environments.
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
    --gke)  GKE_LOGIN="true"
    ;;
    *) error "Unknown parameter passed: $i"; exit 1 ;;
esac
done

# ===================== Login to GCP
info "Logging in to Google Cloud..."
gcloud auth activate-service-account \
    $SERVICE_ACCOUNT \
    --key-file=$GOOGLE_APPLICATION_CREDENTIALS --project=$GCP_PROJECT

if [ ! -z "$GKE_LOGIN" ]; then
    # ===================== Login to GKE
    info "Logging in to GKE..."
    gcloud config set container/use_client_certificate False
    gcloud container clusters get-credentials "$GKE_CLUSTER" --zone "$GKE_CLUSTER_ZONE" --project "$GCP_PROJECT"
fi