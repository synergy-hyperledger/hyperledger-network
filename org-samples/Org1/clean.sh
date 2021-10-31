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

cd $HLF_NETWORK_DIR

docker_files=" -f docker/docker-compose-ca.yaml -f docker/docker-compose-org.yaml"
if [ "${HLF_CA_ORDR_REQ}" = "Y" ]; then
docker_files="$docker_files -f docker/docker-compose-orderer.yaml"
fi

docker-compose $docker_files down

docker volume prune -f

echo "--------- C L E A R E D -------------"

