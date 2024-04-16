#!/bin/bash

start=$(date +%s)

COLD_DIR=/data

SOURCE_DIR=appliance
DEST_DIR=test_appliance

SERVER_IP=192.168.0.42
DUMMY_VALUE='{pangduck_setting_ip}'

# copy appliance
cd ${COLD_DIR}
rsync -aqh --progress --include-from pangduck_include_files --exclude-from pangduck_exclude_files ${SOURCE_DIR} ${DEST_DIR}

# change config ip data
./replace_conf_data.sh ${DEST_DIR}/${SOURCE_DIR} ${SERVER_IP} ${DUMMY_VALUE}

# copy setting_ip.sh, with dependency replace_conf_data.sh
cp unpackaging.sh ${DEST_DIR} && cp replace_conf_data.sh ${DEST_DIR}

# compress
TODAY=$(TZ=Asia/Seoul date +%Y%m%d)
TAR_FILENAME=${TODAY}_${SOURCE_DIR}.tar.gz
cd ${DEST_DIR} && tar -zcf ${TAR_FILENAME} ${SOURCE_DIR}

# move tar to parent dir
mv ${TAR_FILENAME} ../ && cd ..

# remove destination directory
#rm ${DEST_DIR} -rf

end=$(date +%s)

# print running time
echo running time : $((end - start)) s
