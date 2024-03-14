#!/bin/bash

start=`date +%s`

HOT_DIR=/hot
COLD_DIR=/data

SOURCE_DIR=appliance
DEST_DIR=test_appliance

SERVER_42_IP=211.115.206.6
SERVER_130_IP=211.115.206.5
DUMMY_VALUE='{dti_setting_ip}'

CLICKHOUSE_PARENT=${DEST_DIR}/${SOURCE_DIR}/hotdata/dti/data_node/data
CLICKHOUSE_DIRS=("click" "click2" "click3")

# copy appliance 
cd ${COLD_DIR}
rsync -aqh   --progress --include-from dti_include_files --exclude-from dti_exclude_files ${SOURCE_DIR} ${DEST_DIR}

cd ${HOT_DIR}
rsync -aqh  --progress  --include-from ${COLD_DIR}/dti_include_files --exclude-from ${COLD_DIR}/dti_exclude_files ${SOURCE_DIR} ${COLD_DIR}/${DEST_DIR}

cd ${COLD_DIR}
# restore clickhouse metadata
#for dir in "${CLICKHOUSE_DIRS[@]}"; do
#  rsync -aqh --progress ${CLICKHOUSE_PARENT}/copy/${dir}/metadata ${CLICKHOUSE_PARENT}/${dir}
#done

# change config ip data
./replace_conf_data.sh ${DEST_DIR}/${SOURCE_DIR} ${SERVER_42_IP} ${DUMMY_VALUE}
./replace_conf_data.sh ${DEST_DIR}/${SOURCE_DIR} ${SERVER_130_IP} ${DUMMY_VALUE}

# copy setting_ip.sh, with dependency replace_conf_data.sh
cp unpackaging.sh ${DEST_DIR} && cp replace_conf_data.sh ${DEST_DIR}

# compress
TODAY=`TZ=Asia/Seoul date +%Y%m%d`
TAR_FILENAME=${TODAY}_${SOURCE_DIR}.tar.bz2
cd ${DEST_DIR} && tar --use-compress-prog=pbzip2 -cf ${TAR_FILENAME} ${SOURCE_DIR}

# move tar to parent dir
mv ${TAR_FILENAME} ../ && cd ..

# remove destination directory
rm ${DEST_DIR} -rf

end=`date +%s`

# print running time
echo running time : $((end-start)) s
