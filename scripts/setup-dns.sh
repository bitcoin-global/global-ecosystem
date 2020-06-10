#!/bin/bash

###############################################################################
#
#                             setup-dns.sh
#
# Creates specified dns zone for required hostname and adds a pointer for a 
# specific subdomain to specific IP. 
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
    -d=*|--dns=*)           DNS_NAME="${i#*=}"
    shift ;;
    -d=*|--ip=*)            BIND_IP="${i#*=}"
    shift ;;
    --destroy)              DESTROY="true"
    ;;
    --skip-gcp-ip)          SKIP_GCP_IP="true"
    ;;
    *) error "Unknown parameter passed: $i"; exit 1 ;;
esac
done

# Make sure required params are provided
kill_if_empty "--name" $DNS_ZONE_NAME

# Check if exists
IP_NAME="$DNS_ZONE_NAME-external-ip"
DNS_EXIST=$(gcloud dns managed-zones list --filter="name=$DNS_ZONE_NAME" --format=yaml)
IP_EXISTS=$(gcloud compute addresses list --global --filter="name=$IP_NAME" --format=yaml)

# ====== Do things
if [ -z "$DESTROY" ]; # if not destructive operation
then
    # Ensure DNS is provided
    kill_if_empty "--dns" $DNS_NAME

    # Create DNS zone
    info "Creating dns zone ($DNS_ZONE_NAME) (hostname: $DNS_NAME)..."
    if [ -z "$DNS_EXIST" ];
    then
        warn "Dns zone does not exist, creating..."
        gcloud dns managed-zones create $DNS_ZONE_NAME \
            --description="Infrastructure managed" \
            --dns-name=$DNS_NAME \
            --visibility=public
    else
        warn "Dns zone already exists, skipping..."
    fi

    # Create GCP global ip if said so
    if [ -z "$SKIP_GCP_IP" ]; then
        info "Reserving GCP Global IP ($IP_NAME)..."
    
        if [ -z "$IP_EXISTS" ]; then
            warn "GCP Global IP does not exist, creating..."
            gcloud compute addresses create $IP_NAME --global --ip-version IPV4
        else
            warn "GCP Global IP already exists, skipping..."
        fi
    fi

    # Bind IP to DNS records
    if [[ -z "$SKIP_GCP_IP" || ! -z "$BIND_IP" ]]; then
        info "Configuring DNS records..."
        DNS_RECORDS_LIST=$(gcloud dns record-sets list -z $DNS_ZONE_NAME --format json)

        # Select proper IP
        if [ ! -z "$BIND_IP" ]; then
            IP_ADDRESS="$BIND_IP"
        elif [ -z "$SKIP_GCP_IP" ]; then
            IP_ADDRESS=$(gcloud compute addresses describe $IP_NAME --global --format json | jq '.address' | tr -d '"')
        fi

        # Add selected IP to DNS records
        if grep -q "$IP_ADDRESS" <<<"$DNS_RECORDS_LIST"; then
            warn "IP address ($IP_ADDRESS) already in DNS records, skipping..."
        else
            warn "IP address ($IP_ADDRESS) not in DNS records, adding..."
            gcloud dns record-sets transaction start --zone=$DNS_ZONE_NAME
            gcloud dns record-sets transaction add "$IP_ADDRESS" --name=$DNS_NAME. --ttl=300 --type=A --zone=$DNS_ZONE_NAME
            gcloud dns record-sets transaction execute --zone=$DNS_ZONE_NAME
        fi
    fi

    # Print dns info
    gcloud dns managed-zones describe $DNS_ZONE_NAME

else # if destructive operation
    # Destroy DNS zone if exists
    info "Destroying DNS zone ($DNS_ZONE_NAME)..."
    if [ ! -z "$DNS_EXIST" ];
    then
        warn "DNS zone exists, deleting records..."

        DNS_RECORDS=$(gcloud dns record-sets list --zone=$DNS_ZONE_NAME --format=json | jq '. | 
            map(select(.type != ("NS") and .type != ("SOA")))')
        gcloud dns record-sets transaction start --zone=$DNS_ZONE_NAME
        for row in $(echo "${DNS_RECORDS}" | jq -r '.[] | @base64'); do
            _jq() {
                echo ${row} | base64 --decode | jq -r ${1}
            }

            gcloud dns record-sets transaction remove "$(_jq '.rrdatas[0]')" \
                --name=$(_jq '.name') --ttl=$(_jq '.ttl') --type=$(_jq '.type') \
                --zone=$DNS_ZONE_NAME
        done
        gcloud dns record-sets transaction execute --zone=$DNS_ZONE_NAME
        gcloud dns managed-zones delete $DNS_ZONE_NAME
    else
        warn "DNS zone does not exist, skipping..."
    fi
 
    # Destroy IP if should
    if [[ ! -z "$IP_EXISTS" && -z "$SKIP_GCP_IP" ]]; then
        info "Global GCP IP exists, trying to free..."

        IP_DATA=$(gcloud compute addresses describe $IP_NAME --global --format json)
        IP_ADDRESS=$(echo $IP_DATA | jq '.address' | tr -d '"')
        IP_STATUS=$(echo $IP_DATA | jq '.status' | tr -d '"')
        if [ "$IP_STATUS" == "RESERVED" ]; then
            echo "y" | gcloud compute addresses delete $IP_NAME --global
            warn "IP address ($IP_ADDRESS) freed!"
        else
            warn "IP address ($IP_ADDRESS) not freed. It is used somewhere!"
        fi
    else
        warn "Skipping GCP Global IP..."
    fi
fi

okboat
