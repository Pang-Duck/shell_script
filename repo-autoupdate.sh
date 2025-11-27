#!/bin/bash
# repo-update.sh
# k8s 관련 패키지 로컬 레포

RPM_DIR="/repo/rpm"
DEB_DIR="/repo/deb"
EXCLUDE_REGEX='\.repodata|Packages\.gz|Packages'

inotifywait -m -e create -e delete -e moved_to -e moved_from \
    --exclude "$EXCLUDE_REGEX" \
    "$RPM_DIR" "$DEB_DIR" |
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
        cd "$DEB_DIR"
        dpkg-scanpackages -m . > Packages
        dpkg-scanpackages -m . | gzip -9 > Packages.gz
        cd - > /dev/null
        echo "[INFO] DEB metadata updated."
    fi
done