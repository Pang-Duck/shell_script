#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "usage: appliance_ftp_upload.sh PARENT_DIR FILE_NAME"
  exit 1
fi

PARENT_DIR=$1
FILE_NAME=$2

ftp -i -n <<EOF
  open "192.168.0.40"
  user "ctilab" "deep@!09"
  lcd ${PARENT_DIR}
  cd /HDD2/BACKUP/appliance
  put ${FILE_NAME}
EOF
