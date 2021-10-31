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

HLF_TEMPLATE_DIR=$HLF_HOME/templates

rm -rf $HLF_NETWORK_DIR 

echo "Setting up $ORG_NAME "

mkdir -p $HLF_NETWORK_DIR/docker
mkdir -p $HLF_NETWORK_DIR/organizations/peerOrganizations $HLF_NETWORK_DIR/organizations/ordererOrganizations
mkdir -p $HLF_NETWORK_DIR/fabric-ca/ca-tls $HLF_NETWORK_DIR/fabric-ca/ca-orderer $HLF_NETWORK_DIR/fabric-ca/ca-org

mkdir -p $HLF_NETWORK_DIR/fabric-ca/client
mkdir -p $HLF_NETWORK_DIR/fabric-ca/client/ca-tls $HLF_NETWORK_DIR/fabric-ca/client/ca-orderer $HLF_NETWORK_DIR/fabric-ca/client/ca-org

eval "cat <<EOF
$(cat $HLF_TEMPLATE_DIR/fabric-ca-client.cfg)
EOF
" > $HLF_NETWORK_DIR/fabric-ca/client/fabric-ca-client-config.yaml

eval "cat <<EOF
$(cat $HLF_TEMPLATE_DIR/docker-compose-ca.cfg)
EOF
" > $HLF_NETWORK_DIR/docker/docker-compose-ca.yaml

################################# 
#  TLS CA
################################# 
echo "Setting TLS CA ..."
HLF_CA_CN=${HLF_CA_TLS_CN}
HLF_CA_PORT=${HLF_CA_TLS_PORT}
HLF_CA_ID=${HLF_CA_TLS_ID}
HLF_CA_SECRET=${HLF_CA_TLS_SECRET}
export FABRIC_CA_SERVER_HOME=$HLF_NETWORK_DIR/fabric-ca/ca-tls
eval "cat <<EOF
$(cat $HLF_TEMPLATE_DIR/fabric-ca-server.cfg)
EOF
" > $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml

fabric-ca-server start &
ca_tls_pid=$!
if [ `ps -p $ca_tls_pid | wc -l` -ne 2 ]; then
    echo "TLS CA server FAILED to start"
    exit 1
fi

eval "cat <<EOF
$(cat $HLF_TEMPLATE_DIR/ca.cfg)
EOF
" >> $HLF_NETWORK_DIR/docker/docker-compose-ca.yaml

HLF_CA_TLS_CACERT=$FABRIC_CA_SERVER_HOME/ca-cert.pem
while [ ! -f $HLF_CA_TLS_CACERT ]; do
    echo -n "."
    sleep 1
done
echo -e "\nTLS CA is UP"
export FABRIC_CA_CLIENT_HOME=$HLF_NETWORK_DIR/fabric-ca/client
fabric-ca-client enroll -d --mspdir ca-tls/msp -u https://${HLF_CA_TLS_ID}:${HLF_CA_TLS_SECRET}@${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --tls.certfiles $HLF_CA_TLS_CACERT

## Register and get TLS certs for Orderer CA
if [ "${HLF_CA_ORDR_REQ}" = "Y" ]; then
fabric-ca-client register -d --mspdir ca-tls/msp --id.name ${HLF_CA_ORDR_ID} --id.secret ${HLF_CA_ORDR_SECRET} -u https://${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
fabric-ca-client enroll -d --mspdir ca-tls/${HLF_CA_ORDR_ID}/msp -u https://${HLF_CA_ORDR_ID}:${HLF_CA_ORDR_SECRET}@${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --enrollment.profile tls --csr.hosts ${HLF_CA_HOST} --tls.certfiles $HLF_CA_TLS_CACERT
fi

## Register and get TLS certs for Org CA
fabric-ca-client register -d --mspdir ca-tls/msp --id.name ${HLF_CA_ORG_ID} --id.secret ${HLF_CA_ORG_SECRET} -u https://${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
fabric-ca-client enroll -d --mspdir ca-tls/${HLF_CA_ORG_ID}/msp -u https://${HLF_CA_ORG_ID}:${HLF_CA_ORG_SECRET}@${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --enrollment.profile tls --csr.hosts ${HLF_CA_HOST} --tls.certfiles $HLF_CA_TLS_CACERT

if [ -n "${ca_tls_pid}" ]; then
    kill -15 $ca_tls_pid
fi


#################################
#  ORDERER CA
#################################
if [ "${HLF_CA_ORDR_REQ}" = "Y" ]; then
export FABRIC_CA_SERVER_HOME=$HLF_NETWORK_DIR/fabric-ca/ca-orderer
echo "Setting Orderer CA ..."
HLF_CA_CN=${HLF_CA_ORDR_CN}
HLF_CA_PORT=${HLF_CA_ORDR_PORT}
HLF_CA_ID=${HLF_CA_ORDR_ID}
HLF_CA_SECRET=${HLF_CA_ORDR_SECRET}

HLF_CA_TLS_CERT=tls/cert.pem
HLF_CA_TLS_KEY=tls/key.pem
mkdir -p $FABRIC_CA_SERVER_HOME/tls
cp $HLF_NETWORK_DIR/fabric-ca/client/ca-tls/${HLF_CA_ORDR_ID}/msp/keystore/* $FABRIC_CA_SERVER_HOME/$HLF_CA_TLS_KEY
cp $HLF_NETWORK_DIR/fabric-ca/client/ca-tls/${HLF_CA_ORDR_ID}/msp/signcerts/cert.pem $FABRIC_CA_SERVER_HOME/$HLF_CA_TLS_CERT

eval "cat <<EOF
$(cat $HLF_TEMPLATE_DIR/fabric-ca-server.cfg)
EOF
" > $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml

fabric-ca-server start &
ca_ordr_pid=$!
echo $ca_ordr_pid
if [ `ps -p $ca_ordr_pid | wc -l` -ne 2 ]; then
    echo "ORDERER CA server FAILED to start"
    exit 1
fi
eval "cat <<EOF
$(cat $HLF_TEMPLATE_DIR/ca.cfg)
EOF
" >> $HLF_NETWORK_DIR/docker/docker-compose-ca.yaml

while [ ! -f $FABRIC_CA_SERVER_HOME/ca-cert.pem ]; do
    echo -n "."
    sleep 1
done
echo -e "\n ORDERER CA is UP"

export FABRIC_CA_CLIENT_HOME=$HLF_NETWORK_DIR/fabric-ca/client
fabric-ca-client enroll -d --mspdir ca-orderer/msp -u https://${HLF_CA_ORDR_ID}:${HLF_CA_ORDR_SECRET}@${HLF_CA_HOST}:${HLF_CA_ORDR_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
fabric-ca-client register -d --mspdir ca-orderer/msp --id.name ${HLF_ORDR_ID} --id.secret ${HLF_ORDR_SECRET} --id.type orderer -u https://${HLF_CA_HOST}:${HLF_CA_ORDR_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
fabric-ca-client register -d --mspdir ca-orderer/msp --id.name ${HLF_ORDR_ADMIN_ID} --id.secret ${HLF_ORDR_ADMIN_SECRET} --id.type admin --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert" -u https://${HLF_CA_HOST}:${HLF_CA_ORDR_PORT} --tls.certfiles $HLF_CA_TLS_CACERT

if [ -n "${ca_ordr_pid}" ]; then
    kill -15 $ca_ordr_pid
fi
fi

#################################
#  ORG CA
#################################
export FABRIC_CA_SERVER_HOME=$HLF_NETWORK_DIR/fabric-ca/ca-org
echo "Setting Org CA ..."
HLF_CA_CN=${HLF_CA_ORG_CN}
HLF_CA_PORT=${HLF_CA_ORG_PORT}
HLF_CA_ID=${HLF_CA_ORG_ID}
HLF_CA_SECRET=${HLF_CA_ORG_SECRET}

HLF_CA_TLS_CERT=tls/cert.pem
HLF_CA_TLS_KEY=tls/key.pem
mkdir -p $FABRIC_CA_SERVER_HOME/tls
cp $HLF_NETWORK_DIR/fabric-ca/client/ca-tls/${HLF_CA_ORG_ID}/msp/keystore/* $FABRIC_CA_SERVER_HOME/$HLF_CA_TLS_KEY
cp $HLF_NETWORK_DIR/fabric-ca/client/ca-tls/${HLF_CA_ORG_ID}/msp/signcerts/cert.pem $FABRIC_CA_SERVER_HOME/$HLF_CA_TLS_CERT

eval "cat <<EOF
$(cat $HLF_TEMPLATE_DIR/fabric-ca-server.cfg)
EOF
" > $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml

fabric-ca-server start &
ca_org_pid=$!
echo $ca_org_pid
if [ $(ps -p $ca_org_pid|wc -l) -eq 1 ]; then
    echo "ORG CA server FAILED to start"
    exit 1
fi

eval "cat <<EOF
$(cat $HLF_TEMPLATE_DIR/ca.cfg)
EOF
" >> $HLF_NETWORK_DIR/docker/docker-compose-ca.yaml

while [ ! -f $FABRIC_CA_SERVER_HOME/ca-cert.pem ]; do
    echo -n "."
    sleep 1
done
echo -e "\n ORG CA is UP"

export FABRIC_CA_CLIENT_HOME=$HLF_NETWORK_DIR/fabric-ca/client
fabric-ca-client enroll -d --mspdir ca-org/msp -u https://${HLF_CA_ORG_ID}:${HLF_CA_ORG_SECRET}@${HLF_CA_HOST}:${HLF_CA_ORG_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
fabric-ca-client register -d --mspdir ca-org/msp --id.name ${HLF_ORG_PEER1_ID} --id.secret ${HLF_ORG_PEER1_SECRET} --id.type peer -u https://${HLF_CA_HOST}:${HLF_CA_ORG_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
fabric-ca-client register -d --mspdir ca-org/msp --id.name ${HLF_ORG_ADMIN_ID} --id.secret ${HLF_ORG_ADMIN_SECRET} --id.type admin -u https://${HLF_CA_HOST}:${HLF_CA_ORG_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
fabric-ca-client register -d --mspdir ca-org/msp --id.name ${HLF_ORG_USER_ID} --id.secret ${HLF_ORG_USER_SECRET} --id.type client -u https://${HLF_CA_HOST}:${HLF_CA_ORG_PORT} --tls.certfiles $HLF_CA_TLS_CACERT

if [ -n "${ca_org_pid}" ]; then
    kill -15 $ca_org_pid
fi
sleep 2

##------------------------------------------------

cd $HLF_NETWORK_DIR
export COMPOSE_PROJECT_NAME=net
docker-compose -f docker/docker-compose-ca.yaml up -d

#################################
# SETUP ORDERER 
#################################
if [ "${HLF_CA_ORDR_REQ}" = "Y" ]; then
HLF_ORDR_ORG_DIR=$HLF_NETWORK_DIR/organizations/ordererOrganizations/${ORG_NAME}
HLF_ORDR_DIR=$HLF_ORDR_ORG_DIR/orderers/${HLF_ORDR_ID}
mkdir -p ${HLF_ORDR_ORG_DIR}/msp

eval "cat <<EOF
$(cat $HLF_TEMPLATE_DIR/docker-compose-orderer.cfg)
EOF
" >> $HLF_NETWORK_DIR/docker/docker-compose-orderer.yaml
EXTRA_HOSTS=$(cat $HLF_TEMPLATE_DIR/extra_hosts.txt)
sed -i "s/DOCKER_EXTRA_HOSTS/$EXTRA_HOSTS/g" $HLF_NETWORK_DIR/docker/docker-compose-orderer.yaml

export FABRIC_CA_CLIENT_HOME=$HLF_NETWORK_DIR/fabric-ca/client
fabric-ca-client register -d --mspdir ca-tls/msp --id.name $HLF_ORDR_ID --id.secret $HLF_ORDR_SECRET -u https://${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
export FABRIC_CA_CLIENT_HOME=$HLF_ORDR_ORG_DIR
cp $HLF_NETWORK_DIR/fabric-ca/client/fabric-ca-client-config.yaml $HLF_ORDR_ORG_DIR/

HLF_CA_PORT=${HLF_CA_ORDR_PORT}
eval "cat <<EOF
$(cat $HLF_TEMPLATE_DIR/config.cfg)
EOF
" > $HLF_ORDR_ORG_DIR/config.yaml

fabric-ca-client enroll -d -M orderers/${HLF_ORDR_ID}/msp -u https://${HLF_ORDR_ID}:${HLF_ORDR_SECRET}@${HLF_CA_HOST}:${HLF_CA_ORDR_PORT} --csr.hosts "${HLF_ORDR_ID},${HLF_CA_HOST}" --tls.certfiles $HLF_CA_TLS_CACERT
fabric-ca-client enroll -d -M orderers/${HLF_ORDR_ID}/tls -u https://${HLF_ORDR_ID}:${HLF_ORDR_SECRET}@${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --enrollment.profile tls --csr.hosts "${HLF_ORDR_ID},${HLF_CA_HOST}" --tls.certfiles $HLF_CA_TLS_CACERT
fabric-ca-client enroll -d -M users/Admin@${ORG_NAME}/msp -u https://${HLF_ORDR_ADMIN_ID}:${HLF_ORDR_ADMIN_SECRET}@${HLF_CA_HOST}:${HLF_CA_ORDR_PORT} --tls.certfiles $HLF_CA_TLS_CACERT

mv $HLF_ORDR_DIR/tls/keystore/* $HLF_ORDR_DIR/tls/keystore/key.pem
cp $HLF_ORDR_DIR/tls/tlscacerts/tls-* $HLF_ORDR_DIR/tls/tlscacerts/tls-cacert.pem
cp -r $HLF_ORDR_DIR/tls/tlscacerts $HLF_ORDR_ORG_DIR/msp/
cp -r $HLF_ORDR_DIR/msp/cacerts $HLF_ORDR_ORG_DIR/msp/
cp $HLF_ORDR_ORG_DIR/msp/cacerts/* $HLF_ORDR_ORG_DIR/msp/cacerts/cacert.pem
cp -r $HLF_ORDR_DIR/tls/tlscacerts $HLF_ORDR_DIR/msp/
cp $HLF_ORDR_ORG_DIR/config.yaml $HLF_ORDR_DIR/msp/
cp $HLF_ORDR_ORG_DIR/config.yaml $HLF_ORDR_ORG_DIR/msp/
cp $HLF_ORDR_ORG_DIR/config.yaml $HLF_ORDR_ORG_DIR/users/Admin@${ORG_NAME}/msp/
fi

#-------------------------------------------


#################################
# SETUP ORG
#################################

get_val() {
   var1=$1
   echo ${!var1} 
}

HLF_ORG_DIR=$HLF_NETWORK_DIR/organizations/peerOrganizations/${ORG_NAME}
mkdir -p $HLF_ORG_DIR/msp

HLF_PEER_NUM=1
HLF_ORG_PEER_ID=$(get_val HLF_ORG_PEER${HLF_PEER_NUM}_ID)
HLF_ORG_PEER_SECRET=$(get_val HLF_ORG_PEER${HLF_PEER_NUM}_SECRET)
HLF_ORG_PEER_PORT=$(get_val HLF_ORG_PEER${HLF_PEER_NUM}_PORT)
HLF_ORG_PEER_CC_PORT=$(get_val HLF_ORG_PEER${HLF_PEER_NUM}_CC_PORT)
HLF_ORG_PEER_COUCHDB=$(get_val HLF_ORG_PEER${HLF_PEER_NUM}_COUCHDB)
HLF_ORG_PEER_COUCHDB_USER=$(get_val HLF_ORG_PEER${HLF_PEER_NUM}_COUCHDB_USER)
HLF_ORG_PEER_COUCHDB_PASSWD=$(get_val HLF_ORG_PEER${HLF_PEER_NUM}_COUCHDB_PASSWD)
HLF_ORG_PEER_COUCHDB_PORT=$(get_val HLF_ORG_PEER${HLF_PEER_NUM}_COUCHDB_PORT)
HLF_ORG_PEER_DIR=$HLF_ORG_DIR/peers/${HLF_ORG_PEER_ID}

export FABRIC_CA_CLIENT_HOME=$HLF_NETWORK_DIR/fabric-ca/client
fabric-ca-client register -d --mspdir ca-tls/msp --id.name $HLF_ORG_PEER_ID --id.secret $HLF_ORG_PEER_SECRET -u https://${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --tls.certfiles $HLF_CA_TLS_CACERT

export FABRIC_CA_CLIENT_HOME=$HLF_ORG_DIR
cp $HLF_NETWORK_DIR/fabric-ca/client/fabric-ca-client-config.yaml $HLF_ORG_DIR/

HLF_CA_PORT=${HLF_CA_ORG_PORT}
eval "cat <<EOF
$(cat $HLF_TEMPLATE_DIR/config.cfg)
EOF
" > $HLF_ORG_DIR/config.yaml

fabric-ca-client enroll -d -M peers/$HLF_ORG_PEER_ID/msp -u https://${HLF_ORG_PEER_ID}:${HLF_ORG_PEER_SECRET}@${HLF_CA_HOST}:${HLF_CA_ORG_PORT} --csr.hosts "${HLF_ORG_PEER_ID},${HLF_CA_HOST}" --tls.certfiles $HLF_CA_TLS_CACERT
fabric-ca-client enroll -d -M peers/$HLF_ORG_PEER_ID/tls -u https://${HLF_ORG_PEER_ID}:${HLF_ORG_PEER_SECRET}@${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --enrollment.profile tls --csr.hosts "${HLF_ORG_PEER_ID},${HLF_CA_HOST}" --tls.certfiles $HLF_CA_TLS_CACERT

mv $HLF_ORG_PEER_DIR/tls/keystore/* $HLF_ORG_PEER_DIR/tls/keystore/key.pem
cp $HLF_ORG_PEER_DIR/tls/tlscacerts/tls-* $HLF_ORG_PEER_DIR/tls/tlscacerts/tls-cacert.pem
cp $HLF_ORG_DIR/config.yaml $HLF_ORG_PEER_DIR/msp/
cp $HLF_ORG_DIR/config.yaml $HLF_ORG_DIR/msp/
cp -r $HLF_ORG_PEER_DIR/tls/tlscacerts $HLF_ORG_DIR/msp/
cp -r $HLF_ORG_PEER_DIR/msp/cacerts $HLF_ORG_DIR/msp/
cp $HLF_ORG_DIR/msp/cacerts/* $HLF_ORG_DIR/msp/cacerts/cacert.pem
#cp -r $HLF_ORG_PEER_DIR/tls/tlscacerts $HLF_ORG_DIR/tlsca
#cp -r $HLF_ORG_PEER_DIR/msp/cacerts $HLF_ORG_DIR/ca

fabric-ca-client enroll -d -M users/User1@$ORG_NAME/msp -u https://${HLF_ORG_USER_ID}:${HLF_ORG_USER_SECRET}@${HLF_CA_HOST}:${HLF_CA_ORG_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
fabric-ca-client enroll -d -M users/Admin@$ORG_NAME/msp -u https://${HLF_ORG_ADMIN_ID}:${HLF_ORG_ADMIN_SECRET}@${HLF_CA_HOST}:${HLF_CA_ORG_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
cp $HLF_ORG_DIR/config.yaml $HLF_ORG_DIR/users/User1@$ORG_NAME/msp/
cp $HLF_ORG_DIR/config.yaml $HLF_ORG_DIR/users/Admin@$ORG_NAME/msp/

eval "cat <<EOF
$(cat $HLF_TEMPLATE_DIR/docker-compose-org.cfg)
EOF
" > $HLF_NETWORK_DIR/docker/docker-compose-org.yaml
EXTRA_HOSTS=$(cat $HLF_TEMPLATE_DIR/extra_hosts.txt)
sed -i "s/DOCKER_EXTRA_HOSTS/$EXTRA_HOSTS/g" $HLF_NETWORK_DIR/docker/docker-compose-org.yaml

##--------------------------------------------

mkdir -p $HLF_NETWORK_DIR/configtx $HLF_NETWORK_DIR/channel-artifacts $HLF_NETWORK_DIR/system-genesis-block
#mkdir -p $HLF_NETWORK_DIR/config
eval "cat <<EOF
$(cat $HLF_TEMPLATE_DIR/configtx.cfg)
EOF
" > $HLF_NETWORK_DIR/configtx/configtx.yaml
#cp $HLF_HOME/config/* $HLF_NETWORK_DIR/config/


##########################################
## Channel Connection Profile (CCP)
##########################################

sh ccp-generate.sh

##--------------------------------------------


