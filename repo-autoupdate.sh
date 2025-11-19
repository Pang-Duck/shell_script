#!/bin/bash
# repo-update.sh
# k8s 관련 패키지 로컬 레포

RPM_DIR="/repo/rpm"
DEB_DIR="/repo/deb"

inotifywait -m -e create -e delete -e moved_to -e moved_from "$RPM_DIR" "$DEB_DIR" |
while read -r path action file; do
    echo "[INFO] Change detected: $file ($action) in $path"

    # RPM repo 변경
    if [[ "$path" == "$RPM_DIR/"* ]]; then
        echo "[INFO] Updating RPM metadata..."
        createrepo --update "$RPM_DIR"
        echo "[INFO] RPM metadata updated."     
    fi

    # DEB repo 변경
    if [[ "$path" == "$DEB_DIR/"* ]]; then
        echo "[INFO] Updating DEB metadata..."
        cd "$DEB_BASE"
        dpkg-scanpackages -m $DEB_DIR > Packages
        dpkg-scanpackages -m $DEB_DIR | gzip -9 > Packages.gz
        echo "[INFO] DEB metadata updated."
    fi
done