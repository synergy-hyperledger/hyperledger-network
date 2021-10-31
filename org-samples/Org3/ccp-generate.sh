#!/bin/bash

if [ $# -eq 0 ]; then
    if [ ! -f hlf_vars ]; then
        echo "hlf_vars file NOT found. Exiting ..."
        exit 1
    fi
    . ./hlf_vars
else
    vars_file=$1
    if [ ! -f $vars_file ]; then
        echo "$vars_file NOT found. Exiting ..."
        exit 1
    fi
    . ${vars_file}
fi

function one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

function json_ccp {
    local PP=$(one_line_pem $1)
    local CP=$(one_line_pem $2)
    sed -e "s#PEERPEM#$PP#" \
        -e "s#CAPEM#$CP#" \
        -e "s#ORG_NAME#$ORG_NAME#" \
        -e "s#NETWORK#$NETWORK#" \
        -e "s#CA_PORT#$CA_PORT#" \
        -e "s#PEER_ID#$PEER_ID#" \
        -e "s#PEER_PORT#$PEER_PORT#" \
        -e "s#CA_HOST#$CA_HOST#" \
        $HLF_HOME/templates/ccp-template.json
}

function yaml_ccp {
    local PP=$(one_line_pem $1)
    local CP=$(one_line_pem $2)
    sed -e "s#PEERPEM#$PP#" \
        -e "s#CAPEM#$CP#" \
        -e "s#ORG_NAME#$ORG_NAME#" \
        -e "s#NETWORK#$NETWORK#" \
        -e "s#CA_PORT#$CA_PORT#" \
        -e "s#PEER_ID#$PEER_ID#" \
        -e "s#PEER_PORT#$PEER_PORT#" \
        -e "s#CA_HOST#$CA_HOST#" \
        $HLF_HOME/templates/ccp-template.yaml | sed -e $'s/\\\\n/\\\n          /g'
}

PEERPEM=$HLF_NETWORK_DIR/organizations/peerOrganizations/$ORG_NAME/msp/tlscacerts/tls-cacert.pem
CAPEM=$HLF_NETWORK_DIR/organizations/peerOrganizations/$ORG_NAME/msp/cacerts/cacert.pem
ORG_NAME=$ORG_NAME
NETWORK=$(basename $HLF_NETWORK_DIR)
CA_PORT=$HLF_CA_ORG_PORT
PEER_ID=$HLF_ORG_PEER1_ID
PEER_PORT=$HLF_ORG_PEER1_PORT
CA_HOST=$HLF_CA_HOST

echo "$(json_ccp $PEERPEM $CAPEM)" > $HLF_NETWORK_DIR/organizations/peerOrganizations/$ORG_NAME/ccp-$ORG_NAME.json
echo "$(yaml_ccp $PEERPEM $CAPEM)" > $HLF_NETWORK_DIR/organizations/peerOrganizations/$ORG_NAME/ccp-$ORG_NAME.yaml

