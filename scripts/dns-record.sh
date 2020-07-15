#!/bin/bash

###############################################################################
#
#                             dns-record.sh
#
# Adds record to GCP DNS.
# IP can also be created.
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
    -n=*|--name=*)          DNS_ZONE_NAME="${i#*=}" 
    shift ;;
    -d=*|--domain=*)        DOMAIN_VALUE="${i#*=}"
    shift ;;
    -p=*|--parent=*)        PARENT_VALUE="${i#*=}"
    shift ;;
    -t=*|--type=*)          DOMAIN_TYPE="${i#*=}"
    shift ;;
    --ttl=*)                TTL_VALUE="${i#*=}"
    shift ;;
    *) error "Unknown parameter passed: $i"; exit 1 ;;
esac
done

# Make sure required params are provided
kill_if_empty "--name" $DNS_ZONE_NAME

warn "Adding ($DOMAIN_VALUE) to DNS records ($DNS_ZONE_NAME)..."

DNS_RECORDS_LIST=$(gcloud dns record-sets list -z $DNS_ZONE_NAME --format json | jq ".[] | select(.name==\"$DOMAIN_VALUE.\")")
PARENT_DOMAIN=$(sed 's/.*\.\(.*\..*\)/\1/' <<< $DOMAIN_VALUE)
PARENT_DOMAIN=${PARENT_VALUE:-$PARENT_DOMAIN}
TTL_VALUE=${TTL_VALUE:-300}

# Add selected IP to DNS records
if [ ! -z "$DNS_RECORDS_LIST" ]; then
    warn "Data ($DOMAIN_VALUE) already in DNS records, skipping..."
else
    warn "Data ($DOMAIN_VALUE) not in DNS records, adding..."
    gcloud dns record-sets transaction start --zone=$DNS_ZONE_NAME
    gcloud dns record-sets transaction add "$PARENT_DOMAIN." --name="$DOMAIN_VALUE." --ttl=$TTL_VALUE --type=$DOMAIN_TYPE --zone=$DNS_ZONE_NAME
    gcloud dns record-sets transaction execute --zone=$DNS_ZONE_NAME
fi
