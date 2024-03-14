#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "usage: ftp_delete_exceed_num.sh TARGET_DIR NUMBER"
  exit 1
fi

TARGET_DIR=$1
MAINTENANCE_NUMBER=$2

function ftp_ls() {
  ftp -i -n <<EOF
    open "192.168.0.40"
    user "ctilab" "deep@!09"
    cd /HDD2/BACKUP/$1
    ls -1
EOF
}

function ftp_delete_files() {
  path=$1;
  shift
  ftp -i -n <<EOF
    open "192.168.0.40"
    user "ctilab" "deep@!09"
    cd /HDD2/BACKUP/$path
    mdelete $@
EOF
}

FILES=(`ftp_ls ${TARGET_DIR} | grep "${TARGET_DIR}.tar.gz"`)

if [ ${#FILES[@]} -gt "${MAINTENANCE_NUMBER}" ]; then
  DELETE_NUMBER=`expr ${#FILES[@]} - ${MAINTENANCE_NUMBER}`
  ftp_delete_files ${TARGET_DIR} ${FILES[@]:0:$DELETE_NUMBER}
fi
