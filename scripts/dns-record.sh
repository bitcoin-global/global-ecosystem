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
    -p=*|--value=*)         PARENT_VALUE="${i#*=}"
    shift ;;
    -t=*|--type=*)          DOMAIN_TYPE="${i#*=}"
    shift ;;
    --project=*)            GCP_PROJECT="${i#*=}"
    shift ;;
    --ttl=*)                TTL_VALUE="${i#*=}"
    shift ;;
    --cf)                   CLOUDFLARE=true
    shift ;;
    *) error "Unknown parameter passed: $i"; exit 1 ;;
esac
done

# Make sure required params are provided
kill_if_empty "--name" $DNS_ZONE_NAME
ADDITIONAL_CONFIG=""
if [ ! -z "$GCP_PROJECT" ]; then
    ADDITIONAL_CONFIG="--project $GCP_PROJECT"
fi
DOMAIN_TYPE=${DOMAIN_TYPE:-A}

warn "Adding ($DOMAIN_VALUE) to DNS records ($DNS_ZONE_NAME)..."

# Add selected IP to DNS records
if [ -z "${CLOUDFLARE}" ]; then
    DNS_RECORDS_LIST=$(gcloud dns record-sets list -z $DNS_ZONE_NAME $ADDITIONAL_CONFIG --format json | jq ".[] | select(.name==\"$DOMAIN_VALUE.\")")
    PARENT_DOMAIN=$(sed 's/.*\.\(.*\..*\)/\1/' <<< $DOMAIN_VALUE)
    PARENT_VALUE=${PARENT_VALUE:-$PARENT_DOMAIN.}
    TTL_VALUE=${TTL_VALUE:-300}

    if [ ! -z "$DNS_RECORDS_LIST" ]; then
        warn "Data ($DOMAIN_VALUE) already in DNS records, skipping..."
    else
        warn "Data ($DOMAIN_VALUE) not in DNS records, adding..."
        gcloud dns record-sets transaction start $ADDITIONAL_CONFIG --zone=$DNS_ZONE_NAME
        gcloud dns record-sets transaction add "$PARENT_VALUE" --name="$DOMAIN_VALUE." --ttl=$TTL_VALUE --type=$DOMAIN_TYPE $ADDITIONAL_CONFIG --zone=$DNS_ZONE_NAME
        gcloud dns record-sets transaction execute $ADDITIONAL_CONFIG --zone=$DNS_ZONE_NAME
    fi
else
    ### TO CLOUDFLARE
    # get the zone id for the requested zone
    zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DNS_ZONE_NAME&status=active" \
            -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0] | .id')

    # get the dns record id
    dnsrecordid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$DOMAIN_VALUE" \
                -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" \
                -H "X-Auth-Key: ${CLOUDFLARE_API_TOKEN}" \
                -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0] | .id')

    # update the record
    if [ "$dnsrecordid" == "null" ]; then
        result=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/" \
                    -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" \
                    -H "X-Auth-Key: ${CLOUDFLARE_API_TOKEN}" \
                    -H "Content-Type: application/json" \
                    --data "{\"type\":\"$DOMAIN_TYPE\",\"name\":\"$DOMAIN_VALUE\",\"content\":\"$PARENT_VALUE\",\"proxied\":false}")
    else
        result=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dnsrecordid" \
                    -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" \
                    -H "X-Auth-Key: ${CLOUDFLARE_API_TOKEN}" \
                    -H "Content-Type: application/json" \
                    --data "{\"type\":\"$DOMAIN_TYPE\",\"name\":\"$DOMAIN_VALUE\",\"content\":\"$PARENT_VALUE\",\"proxied\":false}")
    fi

    ### Throw error code
    if [ "$(echo $result | jq .errors[].code)" == "81057" ]; then ## Already exists, skip error
        exit 0
    fi
    if [ "$(echo $result | jq .success)" == "false" ]; then
        echo "ERROR: Something went wrong!"
        echo $result | jq
        exit 1
    fi
fi