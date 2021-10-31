#!/bin/bash

### Dammavalam, Srirangam
### 01-JUN-2021

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

cd $HLF_NETWORK_DIR

########################################
# ADD ORG
########################################

NEW_ORG_NAME=Org3

export FABRIC_CFG_PATH=${HLF_HOME}/config/

export CORE_PEER_LOCALMSPID=${ORG_NAME}MSP
export CORE_PEER_ADDRESS=${HLF_CA_HOST}:7051
export CORE_PEER_MSPCONFIGPATH=$HLF_NETWORK_DIR/organizations/peerOrganizations/${ORG_NAME}/users/Admin@${ORG_NAME}/msp
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_TLS_ROOTCERT_FILE=$HLF_NETWORK_DIR/organizations/peerOrganizations/${ORG_NAME}/peers/${HLF_ORG_PEER1_ID}/tls/tlscacerts/tls-cacert.pem
export ORDERER_CA=$HLF_NETWORK_DIR/organizations/ordererOrganizations/Org1/msp/tlscacerts/tls-cacert.pem
export ORDERER_ADDRESS=centos81:7050


peer channel update -f channel-artifacts/${NEW_ORG_NAME}_update_in_envelope.pb -c mytestchannel -o centos81:7050 --ordererTLSHostnameOverride $HLF_ORDR_ID --tls --cafile $ORDERER_CA



