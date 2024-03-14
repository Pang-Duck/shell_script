#!/bin/bash

start=`date +%s`

HOT_DIR=/hot
COLD_DIR=/data

SOURCE_DIR=test_appliance
DEST_DIR=test_appliance

SERVER_IP=192.168.0.42
DUMMY_VALUE='{dti_setting_ip}'

#/hot/appliance/hotdata/dti/data_node/data
CLICKHOUSE_PARENT=${DEST_DIR}/${SOURCE_DIR}/hotdata/dti/data_node/data
CLICKHOUSE_DIRS=("click" "click2" "click3")

# copy appliance 

cd ${HOT_DIR}
rsync -aqh --progress --include-from ${COLD_DIR}/dti_include_files --exclude-from ${COLD_DIR}/dti_exclude_files ${SOURCE_DIR} ${COLD_DIR}/${DEST_DIR}

cd ${COLD_DIR}

# restore clickhouse metadata
for dir in "${CLICKHOUSE_DIRS[@]}"; do
  rsync -aqh --progress ${CLICKHOUSE_PARENT}/copy/${dir}/metadata ${CLICKHOUSE_PARENT}/${dir}
done

end=`date +%s`

# print running time
echo running time : $((end-start)) s
