#!/bin/bash

# DNS API details need to be set before
API_URL="" 
EMAIL=""
PASSWORD=""

# DNS servers for propagation checking
DNS_SERVERS=""

# Function to display usage information
usage() {
    echo "Usage: $0 [options] <action> <domain> <value>"
    echo
    echo "This script manages DNS TXT records for ACME challenges."
    echo
    echo "Options:"
    echo "  -I    Interactive mode"
    echo
    echo "Actions:"
    echo "  present    Add a TXT record"
    echo "  cleanup    Remove a TXT record"
    echo
    echo "Arguments:"
    echo "  domain     The domain name for the TXT record"
    echo "  value      The value of the TXT record"
    echo
    echo "Examples:"
    echo "  $0 present example.com \"my_challenge_token\""
    echo "  $0 cleanup example.com \"my_challenge_token\""
    echo "  $0 -I"
    echo
    echo "When called by Lego, this script receives 5 arguments:"
    echo "  \$1: action (present or cleanup)"
    echo "  \$2: --"
    echo "  \$3: domain"
    echo "  \$4: token (unused in this script)"
    echo "  \$5: TXT record value"
}

# Function to set DNS TXT record
set_txt_record() {
    local domain="$1"
    local txt_value="$2"

    echo "Executing: curl -X POST -d \"$txt_value\" --user \"$EMAIL:********\" \"$API_URL/_acme-challenge.$domain/TXT\""
    curl -X POST -d "$txt_value" --user $EMAIL:$PASSWORD $API_URL/_acme-challenge.$domain/TXT
    if [ $? -ne 0 ]; then
        echo "Failed to set DNS TXT record" >&2
        exit 1
    fi

    echo "DNS TXT record set successfully"
}

# Function to remove DNS TXT record
remove_txt_record() {
    local domain="$1"
    local txt_value="$2"

    echo "Executing: curl -X DELETE -d \"$txt_value\" --user \"$EMAIL:********\" \"$API_URL/_acme-challenge.$domain/TXT\""
    curl -X DELETE -d "$txt_value" --user $EMAIL:$PASSWORD $API_URL/_acme-challenge.$domain/TXT
    
    if [ $? -ne 0 ]; then
        echo "Failed to remove DNS TXT record" >&2
        exit 1
    fi

    echo "DNS TXT record removed successfully"
}

# Function to check DNS propagation
check_propagation() {
    local domain="$1"
    local expected_value="$2"
    local max_attempts=20
    local wait_time=30

    for dns_server in $DNS_SERVERS; do
        echo "Checking propagation using DNS server: $dns_server"
        for ((i=1; i<=max_attempts; i++)); do
            result=$(dig @"$dns_server" +short TXT "_acme-challenge.$domain")
            if [[ "$result" == *"$expected_value"* ]]; then
                echo "DNS propagation confirmed for $dns_server"
                return 0
            fi
