#!/bin/bash

###############################################################################
#
#                             deploy-cicd.sh
#
# This is the deployment script for required CI/CD infrastructure for shared
# projects. 
#
###############################################################################
set -eo pipefail

# Make sure common.sh is here.
SCRIPT_ROOT=$(dirname $(readlink -f "$0"))
. "${SCRIPT_ROOT}/common.sh" || { echo "Unable to load common.sh"; exit 1; }

# Config
ARTIFACT_NAME=${CONCOURSE_NAME:-concourse}
ARTIFACT_VERSION=${CONCOURSE_VERSION:-11.1.0}

CONCOURSE_SECRETS_FOLDER=${CONCOURSE_SECRETS_FOLDER:-ignore.secret}
CONCOURSE_GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID:-5c1c9014a8c93bdf5cc2}
CONCOURSE_GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET:-}

###############################################################################
# ===================== Creating secrets
###############################################################################
info "Creating secrets..."

SECRET_FOLDER=${ARTIFACT_NAME:-secrets}
OVERRIDES_FILE=$(mktemp /tmp/overrides.XXXXXX)

mkdir $SECRET_FOLDER || true
cd $SECRET_FOLDER

ssh-keygen -t rsa -f host-key  -N '' -m PEM
ssh-keygen -t rsa -f worker-key  -N '' -m PEM
ssh-keygen -t rsa -f session-signing-key  -N '' -m PEM
rm session-signing-key.pub

printf "%s" "$(openssl rand -base64 24)" > encryption-key
printf "%s" "$(openssl rand -base64 24)" > web-encryption-key
printf "%s:%s" "admin" "$(openssl rand -base64 24)" > local-users

echo -n "$CONCOURSE_GITHUB_CLIENT_ID" > github-client-id
echo -n "$CONCOURSE_GITHUB_CLIENT_SECRET" > github-client-secret

echo -n "admin" > postgresql-user
echo -n "$(openssl rand -base64 24)" > postgresql-password
cat <<EOF > $OVERRIDES_FILE
postgresql:
  postgresqlUsername: $(cat postgresql-user)
  postgresqlPassword: $(cat postgresql-password)
EOF

# move secrets
mkdir concourse web worker || true

# worker secrets
mv host-key.pub worker/host-key-pub
mv worker-key.pub worker/worker-key-pub
mv worker-key worker/worker-key

# web secrets
mv session-signing-key web/session-signing-key
mv host-key web/host-key
mv local-users web/local-users
mv web-encryption-key web/encryption-key
mv github-client-id web/github-client-id
mv github-client-secret web/github-client-secret
cp worker/worker-key-pub web/worker-key-pub

# concourse secrets
mv encryption-key concourse/encryption-key
mv postgresql-password concourse/postgresql-password
mv postgresql-user concourse/postgresql-user

cd ..

###############################################################################
# ===================== Installing K8S dependencies
###############################################################################
info "Configuring Google dependencies and Kubernetes secrets..."

# ===================== Ensure logged in to GCP
# ${SCRIPT_ROOT}/login.sh

# ===================== Configuring GCP DNS configs
${SCRIPT_ROOT}/setup-dns.sh --name="dev-bitcoin-global" --dns="bitcoin-global.dev"
${SCRIPT_ROOT}/dns-record.sh --name="dev-bitcoin-global" --domain="ci.bitcoin-global.dev" --type="CNAME"

# ===================== Adding K8s secrets
INSTALLED_CHARTS=$(helm list -oyaml)
if grep -q "$ARTIFACT_NAME" <<<"$INSTALLED_CHARTS"; then
  warn "Secrets shouldn't be updated for existing charts, skipping..."
else
  info "Adding secrets to K8s..."
  kubectl create secret generic $ARTIFACT_NAME-worker --from-file=$SECRET_FOLDER/worker/ \
      --dry-run=client -o yaml | kubectl apply -f -
  kubectl create secret generic $ARTIFACT_NAME-web --from-file=$SECRET_FOLDER/web/ \
      --dry-run=client -o yaml | kubectl apply -f -
  kubectl create secret generic $ARTIFACT_NAME-concourse --from-file=$SECRET_FOLDER/concourse/ \
      --dry-run=client -o yaml | kubectl apply -f -
fi
rm -rf $SECRET_FOLDER

cat <<EOF | kubectl apply -f -
apiVersion: networking.gke.io/v1beta2
kind: ManagedCertificate
metadata:
  name: $ARTIFACT_NAME-certs
spec:
  domains:
    - bitcoin-global.dev
    - ci.bitcoin-global.dev
EOF

# ===================== Installing Helm chart
info "Installing $ARTIFACT_NAME helm chart..."
helm repo add concourse https://concourse-charts.storage.googleapis.com/
helm upgrade --version 11.1.0 -f ../charts/concourse/values.yaml -f $OVERRIDES_FILE $ARTIFACT_NAME concourse/concourse \
    --install --wait --timeout 10m0s --atomic

# ===================== Installing Helm chart
info "Adding post-installation data..."
for filename in $(find "$CONCOURSE_SECRETS_FOLDER/" -maxdepth 1 -type d)
do
  secret_name=${filename##*/}
  if [ ! -z "$secret_name" ]
  then
    kubectl create secret generic $secret_name -n $ARTIFACT_NAME-main --from-file="$filename/" \
      --dry-run=client -o yaml | kubectl apply -f -
  fi
done
