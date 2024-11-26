#!/bin/bash
#### ansible hosts를 읽어 key 파일 복사 ####

HOSTS_FILE="./hosts"

SSH_KEY="$HOME/.ssh/id_rsa.pub"

# hosts 파일에서 ansible_host IP 추출
IPS=$(grep -E "^\s*[^#]" "$HOSTS_FILE" | awk '{for (i=1; i<=NF; i++) if ($i ~ /ansible_host=/) {split($i, arr, "="); print arr[2]}}')

for IP in $IPS; do
    echo "Copying SSH key to $IP..."
    ssh-copy-id -i "$SSH_KEY" "$IP"
done

echo "All keys copied successfully."
