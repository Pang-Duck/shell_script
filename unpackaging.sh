#!/bin/bash

start=`date +%s`

DEFAULT_ROOT='appliance'
OLD_VALUE='{dti_setting_ip}'
SETTING_IP=''

OLD_HOT_PATH="${DEFAULT_ROOT}/hotdata"
NEW_HOT_PATH="/Hot/appliance"

OLD_COLD_PATH="${DEFAULT_ROOT}/colddata"
NEW_COLD_PATH="/Cold/appliance"

if [ "$#" -eq 0 ]; then
  printf 'input new ip: '
  read SETTING_IP
elif [ "$#" -eq 1 ]; then
  SETTING_IP=$1
elif [ "$#" -eq 2 ]; then
  OLD_VALUE=$1
  SETTING_IP=$2
else
  echo "usage: unpackaging.sh [OLD_VALUE] [SETTING_IP]"
  exit 1
fi

# remove exist dirs
rm ${DEFAULT_ROOT} -rf

# unpacking
find *appliance.tar.gz |xargs -n 1 tar -zxf

# change config
./replace_conf_data.sh ${DEFAULT_ROOT} ${OLD_VALUE} ${SETTING_IP}

# if exist file in DTI dirs then rm
rm ${NEW_COLD_PATH}/colddata ${NEW_HOT_PATH}/hotdata -rf

# mkdir new path root
mkdir -p ${NEW_COLD_PATH} ${NEW_HOT_PATH}

# mv to DTI dirs structure
mv ${OLD_COLD_PATH} ${NEW_COLD_PATH} && mv ${OLD_HOT_PATH} ${NEW_HOT_PATH}

# remove empty files
rm ${DEFAULT_ROOT} -rf

end=`date +%s`

# print running time
echo running time : $((end-start)) s
