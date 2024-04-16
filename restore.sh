#!/bin/bash

if [ "$#" -ne 1 ]; then
	echo "usage: setting_ip APPLIANCE_PATH OLD_VALUE NEW_VALUE"
	exit 1
fi

ROOT=$1
BACKUP_PATH=/data/appliance/colddata/pangduck/worker_node/data/backup/reader/$ROOT
RESTORE_PATH=/hot/appliance/hotdata/pangduck/worker_node/data/storm/restore/
mkdir -p restore
cd restore
cp $BACKUP_PATH .

ZIPLIST=($(find . -maxdepth 1 | grep .zip))
mkdir -p temp

for day in ${ZIPLIST[@]}; do
	rm -rf temp/*
	unzip -q $day -d temp 2>/dev/null
	cd temp
	unzip -q "*.zip" 2>/dev/null

	echo $(ls **/* | wc -l)
	#ls **/* |xargs mv -t /home/pangduck/pangduck/larry/result
	ls **/* | xargs mv -t $RESTORE_PATH
	cd ..
done

rm -rf temp
rm *.zip
