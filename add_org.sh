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
export ORDERER_CA=$HLF_NETWORK_DIR/organizations/ordererOrganizations/${HLF_ORDR_ORG_NAME}/msp/tlscacerts/tls-cacert.pem
export ORDERER_ADDRESS=${HLF_ORDR_HOST}:7050

peer channel fetch config ./channel-artifacts/config_block.pb -o ${HLF_ORDR_HOST}:7050 --ordererTLSHostnameOverride $HLF_ORDR_ID -c mytestchannel --tls --cafile $ORDERER_CA

configtxlator proto_decode --input ./channel-artifacts/config_block.pb --type common.Block | jq .data.data[0].payload.data.config > ./channel-artifacts/${NEW_ORG_NAME}MSPconfig.json
#jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"${NEW_ORG_NAME}MSP":.[1]}}}}}' ./channel-artifacts/${NEW_ORG_NAME}MSPconfig.json $HLF_NETWORK_DIR/channel-artifacts/${NEW_ORG_NAME}.json > ./channel-artifacts/${NEW_ORG_NAME}MSPmodified_config.json
#jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"Org3MSP":.[1]}}}}}' ./channel-artifacts/${NEW_ORG_NAME}MSPconfig.json $HLF_NETWORK_DIR/channel-artifacts/${NEW_ORG_NAME}.json > ./channel-artifacts/${NEW_ORG_NAME}MSPmodified_config.json
jq -s ".[0] * {\"channel_group\":{\"groups\":{\"Application\":{\"groups\": {\"${NEW_ORG_NAME}MSP\":.[1]}}}}}" ./channel-artifacts/${NEW_ORG_NAME}MSPconfig.json $HLF_NETWORK_DIR/channel-artifacts/${NEW_ORG_NAME}.json > ./channel-artifacts/${NEW_ORG_NAME}MSPmodified_config.json
configtxlator proto_encode --input ./channel-artifacts/${NEW_ORG_NAME}MSPconfig.json --type common.Config --output ./channel-artifacts/${NEW_ORG_NAME}MSPconfig.pb
configtxlator proto_encode --input ./channel-artifacts/${NEW_ORG_NAME}MSPmodified_config.json --type common.Config --output ./channel-artifacts/${NEW_ORG_NAME}MSPmodified_config.pb
configtxlator compute_update --channel_id "mytestchannel" --original ./channel-artifacts/${NEW_ORG_NAME}MSPconfig.pb --updated ./channel-artifacts/${NEW_ORG_NAME}MSPmodified_config.pb --output ./channel-artifacts/${NEW_ORG_NAME}MSPconfig_update.pb
configtxlator proto_decode --input ./channel-artifacts/${NEW_ORG_NAME}MSPconfig_update.pb --type common.ConfigUpdate --output ./channel-artifacts/${NEW_ORG_NAME}MSPconfig_update.json
echo '{"payload":{"header":{"channel_header":{"channel_id":"'mytestchannel'", "type":2}},"data":{"config_update":'$(cat ./channel-artifacts/${NEW_ORG_NAME}MSPconfig_update.json)'}}}' | jq . > ./channel-artifacts/${NEW_ORG_NAME}_update_in_envelope.json
configtxlator proto_encode --input ./channel-artifacts/${NEW_ORG_NAME}_update_in_envelope.json --type common.Envelope --output ./channel-artifacts/${NEW_ORG_NAME}_update_in_envelope.pb

peer channel signconfigtx -f ./channel-artifacts/${NEW_ORG_NAME}_update_in_envelope.pb

echo "Please submit $HLF_NETWORK_DIR/channel-artifacts/${NEW_ORG_NAME}_update_in_envelope.pb to Org2 to approve"

