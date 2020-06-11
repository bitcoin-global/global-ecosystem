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
info "Installing dependencies..."
sudo apt install -y xclip xsel

###############################################################################
# ===================== Creating secrets
###############################################################################
info "Creating secrets..."
SECRET_FOLDER="concourse-secrets"
mkdir $SECRET_FOLDER || true
cd $SECRET_FOLDER

ssh-keygen -t rsa -f host-key  -N '' -m PEM
ssh-keygen -t rsa -f worker-key  -N '' -m PEM
ssh-keygen -t rsa -f session-signing-key  -N '' -m PEM
rm session-signing-key.pub

echo $POSTGRESQL_USER > postgresql-user
echo $POSTGRESQL_PASS > postgresql-password

# echo $GITHUB_APP_ID > github-client-id
# echo $GITHUB_APP_SECRET > github-client-secret

printf "%s" "$(openssl rand -base64 24)" > encryption-key
printf "%s:%s" "admin" "$(openssl rand -base64 24)" > local-users

mkdir concourse web worker || true

# worker secrets
mv host-key.pub worker/host-key-pub
mv worker-key.pub worker/worker-key-pub
mv worker-key worker/worker-key

# web secrets
mv session-signing-key web/session-signing-key
mv host-key web/host-key
cp worker/worker-key-pub web/worker-key-pub

# other concourse secrets
mv local-users concourse/local-users
mv encryption-key concourse/encryption-key
mv postgresql-password concourse/postgresql-password
mv postgresql-user concourse/postgresql-user
cd ..

###############################################################################
# ===================== Installing K8S dependencies
###############################################################################
info "Configuring Google dependencies and Kubernetes secrets..."

# ===================== Ensure logged in to GCP
./login.sh

# ===================== Configuring GCP DNS configs
./setup-dns.sh --name="dev-bitcoin-global" --dns="bitcoin-global.dev"
./dns-record.sh --name="dev-bitcoin-global" --domain="ci.bitcoin-global.dev" --type="CNAME"

# ===================== Adding K8s secrets
info "Adding secrets to K8s..."
kubectl create secret generic concourse-worker --from-file=$SECRET_FOLDER/worker/ \
    --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic concourse-web --from-file=$SECRET_FOLDER/web/ \
    --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic concourse-main --from-file=$SECRET_FOLDER/concourse/ \
    --dry-run=client -o yaml | kubectl apply -f -
# rm -rf web/* worker/* concourse/*

cat <<EOF | kubectl apply -f -
apiVersion: networking.gke.io/v1beta2
kind: ManagedCertificate
metadata:
  name: concourse-certs
spec:
  domains:
    - bitcoin-global.dev
    - ci.bitcoin-global.dev
EOF

# ===================== Installing Helm chart
info "Installing Concourse helm chart..."
helm repo add concourse https://concourse-charts.storage.googleapis.com/
helm upgrade --version 11.1.0 -f ../charts/concourse/values.yaml concourse concourse/concourse \
    --install --wait --timeout 40m0s --atomic
