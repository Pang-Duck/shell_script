#!/bin/bash

if [ "$#" -ne 2 -a "$#" -ne 3 ]; then
  echo "usage: setting_ip APPLIANCE_PATH OLD_VALUE NEW_VALUE"
  exit 1
fi

ROOT=$1
OLD_VALUE=$2
NEW_VALUE=$3

if [ "${ROOT: -1}" == '/' ]; then
  ROOT=$(echo ${ROOT} | sed 's/\/*$//')
fi

SERVER_IP_CONFIG_PATH=(
  "${ROOT}/colddata/pangduck/data_node/app/click/config*"
  "${ROOT}/colddata/pangduck/worker_node/app/kafka/config/server.properties"
  "${ROOT}/colddata/pangduck/worker_node/app/pangduck.ai.nbad/conf/config.json"
  "${ROOT}/colddata/pangduck/worker_node/app/ds/server/datasources.json"
  "${ROOT}/colddata/pangduck/worker_node/app/detect/config.json"
  "${ROOT}/colddata/pangduck/worker_node/app/pangduckReceiver/conf/EX_Receiver.json"
  "${ROOT}/hotdata/pangduck/data_node/data/click/metadata/pangduck/*"
  "${ROOT}/hotdata/pangduck/data_node/data/click1/metadata/pangduck/*"
  "${ROOT}/hotdata/pangduck/data_node/data/click2/metadata/pangduck/*"
  "${ROOT}/hotdata/pangduck/data_node/data/click3/metadata/pangduck/*"
)

# if old_value is ip format then . -> \.
IP_REGEX='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'
if [[ "$OLD_VALUE" =~ $IP_REGEX ]]; then
  OLD_VALUE=$(echo ${OLD_VALUE} | sed 's/\./\\\./g')
fi

# change config
for path in "${SERVER_IP_CONFIG_PATH[@]}"; do
  find ${path} -exec sed -i "s/${OLD_VALUE}/${NEW_VALUE}/g" {} +
  #  if [ "$?" -ne 0 ]; then
  #    exit 2
  #  fi
done
