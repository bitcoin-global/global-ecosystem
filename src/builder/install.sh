#!/usr/bin/env bash

set -e
set -x

# add gkh user
adduser -S gkh gkh

# install apk packages
apk update
apk --no-cache add ca-certificates gnupg mysql-client openssl ncurses jq ruby python3 ruby-json

# install cloud_sql_proxy & kubectl
gcloud components install -q beta cloud_sql_proxy kubectl

# install helm
curl --silent --show-error --fail --location --output get_helm.sh https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get
chmod 700 get_helm.sh
./get_helm.sh --version "${HELM_VERSION}"
rm get_helm.sh

# install kubeval
curl --silent --show-error --fail --location --output /tmp/kubeval.tar.gz https://github.com/instrumenta/kubeval/releases/download/"${KUBEVAL_VERSION}"/kubeval-linux-amd64.tar.gz
tar -C /usr/local/bin -xf /tmp/kubeval.tar.gz kubeval
rm /tmp/kubeval.tar.gz

# install sops
curl --silent --show-error --fail --location --output /usr/local/bin/sops https://github.com/mozilla/sops/releases/download/"${SOPS_VERSION}"/sops-"${SOPS_VERSION}".linux
chmod 755 /usr/local/bin/sops

# install yq
curl --silent --show-error --fail --location --output /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/"${YQ_BIN_VERSION}"/yq_linux_amd64
chmod 755 /usr/local/bin/yq

# install fly
curl --silent --show-error --fail --location --output /tmp/fly.tgz https://github.com/concourse/concourse/releases/download/v"${FLY_VERSION}"/fly-"${FLY_VERSION}"-linux-amd64.tgz
tar -C /usr/local/bin -xf /tmp/fly.tgz fly
rm /tmp/fly.tgz
chmod 755 /usr/local/bin/fly

# install aviator
curl --silent --show-error --fail --location --output /usr/local/bin/aviator https://github.com/JulzDiverse/aviator/releases/download/v"${AVIATOR_VERSION}"/aviator-linux-amd64
chmod 755 /usr/local/bin/aviator

# set permissions
mkdir -p /data
chown gkh /data /entrypoint.sh /data/commands.sh
chmod +x /entrypoint.sh /data/commands.sh

