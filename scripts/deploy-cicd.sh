#!/bin/bash

###############################################################################
#
#                             deploy-cicd.sh
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

# Install dependencies
info "Installing dependencies...\n"
sudo apt-get update
sudo apt-get install -y build-essential zlibc zlib1g-dev ruby ruby-dev openssl libxslt1-dev libxml2-dev libssl-dev \
    libreadline7 libreadline-dev libyaml-dev libsqlite3-dev sqlite3

info "\nInstalling CLIs...\n"
if bosh -v; then
    info "bosh found, skipping...\n"
else
    warn "bosh not found, installing...\n"
    sudo wget "https://github.com/cloudfoundry/bosh-cli/releases/download/v6.2.1/bosh-cli-6.2.1-linux-amd64" -O /usr/local/bin/bosh
    sudo chmod +x /usr/local/bin/bosh
fi

if control-tower -v; then
    info "control-tower found, skipping...\n"
else
    warn "control-tower not found, installing...\n"
    sudo wget "https://github.com/EngineerBetter/control-tower/releases/download/0.12.1/control-tower-linux-amd64" -O /usr/local/bin/control-tower
    sudo chmod +x /usr/local/bin/control-tower
fi

# Deploy Concourse on GCP
if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then
  error "GOOGLE_APPLICATION_CREDENTIALS is required but not found, exiting..."
fi

# Deployment configuration
GCP_PROJECT=${GCP_PROJECT:-bitcoin-global-playground}
ZONE=${ZONE:-europe-west1-b}

WORKERS=${WORKERS:-1}
WORKER_SIZE=${WORKER_SIZE:-medium}
WEB_SIZE=${WEB_SIZE:-small}
DB_SIZE=${DB_SIZE:-small}

ENABLE_GLOBAL_RESOURCES=${ENABLE_GLOBAL_RESOURCES:-true}

GITHUB_AUTH_CLIENT_ID=${GITHUB_AUTH_CLIENT_ID:-}
GITHUB_AUTH_CLIENT_SECRET=${GITHUB_AUTH_CLIENT_SECRET:-}

PREEMPTIBLE=${PREEMPTIBLE:-true}
SPOT=${SPOT:-true}

warn "Deploying Concourse CI server, this may take up to 20 minutes..."
control-tower deploy --iaas gcp $GCP_PROJECT
control-tower info --iaas gcp $GCP_PROJECT

info "No more tasks, exiting..."
exit 0
