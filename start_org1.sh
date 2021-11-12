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
# Start Orderer
########################################
if [ "${HLF_CA_ORDR_REQ}" = "Y" ]; then
configtxgen -profile TwoOrgsOrdererGenesis -channelID system-channel -outputBlock ./system-genesis-block/genesis.block -configPath ./configtx
configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/mytestchannel.tx -channelID mytestchannel -configPath ./configtx
sleep 30
export COMPOSE_PROJECT_NAME=net
docker-compose -f docker/docker-compose-orderer.yaml up -d
sleep 60
fi


########################################
# Start Peers
########################################

export COMPOSE_PROJECT_NAME=net
docker-compose -f docker/docker-compose-org.yaml up -d
sleep 60

export FABRIC_CFG_PATH=${HLF_HOME}/config/

export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_ADDRESS=${HLF_CA_HOST}:7051
export CORE_PEER_MSPCONFIGPATH=$HLF_NETWORK_DIR/organizations/peerOrganizations/${ORG_NAME}/users/Admin@${ORG_NAME}/msp
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_TLS_ROOTCERT_FILE=$HLF_NETWORK_DIR/organizations/peerOrganizations/${ORG_NAME}/peers/${HLF_ORG_PEER1_ID}/tls/tlscacerts/tls-cacert.pem
export ORDERER_CA=$HLF_NETWORK_DIR/organizations/ordererOrganizations/${HLF_ORDR_ORG_NAME}/msp/tlscacerts/tls-cacert.pem
export ORDERER_ADDRESS=${HLF_ORDR_HOST}:7050


peer channel create -c mytestchannel -f ./channel-artifacts/mytestchannel.tx -o ${HLF_ORDR_HOST}:7050 --ordererTLSHostnameOverride $HLF_ORDR_ID --outputBlock ./channel-artifacts/mytestchannel.block --tls --cafile $ORDERER_CA
sleep 30
peer channel join -b ./channel-artifacts/mytestchannel.block
## set anchor peer
peer channel fetch config ./channel-artifacts/config_block.pb -o ${HLF_ORDR_HOST}:7050 --ordererTLSHostnameOverride $HLF_ORDR_ID -c mytestchannel --tls --cafile $ORDERER_CA
configtxlator proto_decode --input ./channel-artifacts/config_block.pb --type common.Block | jq .data.data[0].payload.data.config > ./channel-artifacts/Org1MSPconfig.json
jq '.channel_group.groups.Application.groups.'Org1MSP'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'${HLF_ORG_PEER1_ID}'","port": '7051'}]},"version": "0"}}' ./channel-artifacts/Org1MSPconfig.json > ./channel-artifacts/Org1MSPmodified_config.json
configtxlator proto_encode --input "./channel-artifacts/Org1MSPconfig.json" --type common.Config >./channel-artifacts/original_config.pb
configtxlator proto_encode --input "./channel-artifacts/Org1MSPmodified_config.json" --type common.Config >./channel-artifacts/modified_config.pb
configtxlator compute_update --channel_id "mytestchannel" --original ./channel-artifacts/original_config.pb --updated ./channel-artifacts/modified_config.pb >./channel-artifacts/config_update.pb
configtxlator proto_decode --input ./channel-artifacts/config_update.pb --type common.ConfigUpdate >./channel-artifacts/config_update.json
echo '{"payload":{"header":{"channel_header":{"channel_id":"'mytestchannel'", "type":2}},"data":{"config_update":'$(cat ./channel-artifacts/config_update.json)'}}}' | jq . >./channel-artifacts/config_update_in_envelope.json
configtxlator proto_encode --input ./channel-artifacts/config_update_in_envelope.json --type common.Envelope >./channel-artifacts/Org1MSPanchors.tx

peer channel update -o ${HLF_ORDR_HOST}:7050 --ordererTLSHostnameOverride $HLF_ORDR_ID -c mytestchannel -f ./channel-artifacts/Org1MSPanchors.tx --tls --cafile $ORDERER_CA


