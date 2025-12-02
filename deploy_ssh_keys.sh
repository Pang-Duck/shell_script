#!/bin/bash
# deploy_ssh_keys.sh
# Ansible 인벤토리 파일을 기반으로 여러 원격 호스트에 SSH 키를 배포하는 스크립트
# - 포트번호 지정 가능
# - 개별 패스워드 모드 지원

INVENTORY_FILE="hosts"

<<<<<<< HEAD
# 인벤토리 파일 존재 확인
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "Error: Inventory file '$INVENTORY_FILE' not found!" >&2
    exit 1
fi
=======
SSH_KEY=($HOME/.ssh/*.pub)
>>>>>>> 48af8c040f4def6db2c66a0f45359a44c9e09061

# 기본 포트 추출
port=$(grep -E "ansible_ssh_port" "$INVENTORY_FILE" | awk -F'=' '{print $2}' | tr -d ' ' || echo "22")

# 개별 패스워드 모드 플래그
individual_passwords=false

# 포트번호 및 옵션 인자 파싱
while getopts ":p:i" opt; do
    case $opt in
    p)
        port="$OPTARG"
        ;;
    i)
        individual_passwords=true
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        echo "Usage: $0 [-p port] [-i]" >&2
        echo "  -p: Specify SSH port (default: from inventory or 22)" >&2
        echo "  -i: Enable individual password mode (ask for each host)" >&2
        exit 1
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
done

# 포트 유효성 검증
if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    echo "Error: Invalid port number '$port'" >&2
    exit 1
fi

echo "Using SSH port: $port"
echo "Home Directory: $HOME"

# SSH 디렉토리 확인 및 생성
if [ ! -d "${HOME}/.ssh" ]; then
    echo "Creating .ssh directory..."
    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"
fi

# SSH 키 생성
if [ ! -f "${HOME}/.ssh/id_rsa.pub" ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -N "" -f "${HOME}/.ssh/id_rsa"
    echo "SSH key generated successfully."
else
    echo "SSH key already exists."
fi

# ansible_user 추출
user=$(grep -E "ansible_user" "$INVENTORY_FILE" | awk -F'=' '{print $2}' | tr -d ' ' | head -n1)

if [ -z "$user" ]; then
    echo "Error: Could not extract ansible_user from inventory file" >&2
    exit 1
fi

echo "Using Ansible user: $user"

# 개별 패스워드 모드가 아닐 때만 공통 패스워드 처리
common_password=""
if [ "$individual_passwords" = false ]; then
    # ansible_password 추출 (환경변수 우선)
    if [ -n "${ANSIBLE_PASSWORD:-}" ]; then
        common_password="$ANSIBLE_PASSWORD"
        echo "Using password from ANSIBLE_PASSWORD environment variable"
    else
        # 인벤토리 파일에서 패스워드 추출 시도
        common_password=$(grep -E "ansible_ssh_pass" "$INVENTORY_FILE" | grep -v '^#' | awk -F'=' '{print $2}' | tr -d ' ' | head -n1 || echo "")
        
        if [ -n "$common_password" ]; then
            echo "Using password from inventory file"
        fi
    fi

    # 패스워드가 여전히 비어있으면 대화형 입력
    if [ -z "$common_password" ]; then
        echo ""
        echo "Password not found in inventory file or environment variable."
        echo "Please enter the SSH password for user '$user' (will be used for all hosts)"
        echo -n ":"
        read -s common_password
        echo ""
        
        if [ -z "$common_password" ]; then
            echo "Error: Password cannot be empty" >&2
            exit 1
        fi
        echo "Using password from interactive input"
    fi
else
    echo "Individual password mode enabled - you will be prompted for each host"
fi

echo "Extracting host IPs from Ansible inventory..."

# 호스트 IP 추출 및 배열로 저장
mapfile -t host_array < <(grep -v '^#' "$INVENTORY_FILE" | grep -Eo 'ansible_host=[0-9.]+' | cut -d= -f2 | grep -v '127.0.0.1' | sort -u)

if [ ${#host_array[@]} -eq 0 ]; then
    echo "Warning: No remote hosts found in inventory file" >&2
    exit 0
fi

# 추출된 호스트 목록 출력
echo "Found hosts:"
printf '%s\n' "${host_array[@]}" | nl
echo "Total host count: ${#host_array[@]}"
echo ""

# 배포 결과 추적 (명시적 초기화)
success_count=0
fail_count=0
failed_hosts=""

# 배포 함수 정의 (stdin 충돌 방지)
deploy_to_host() {
    local ip="$1"
    local password
    
    echo "----------------------------------------"
    
    # 1. 패스워드 결정 로직
    if [ "$individual_passwords" = true ]; then
        echo "Enter password for ${user}@${ip} (or press Enter to skip)"
        echo -n ":"
        
        # exec을 사용하여 tty를 파일 디스크립터 4번에 연결
        exec 4</dev/tty
        if read -r -s password <&4; then
            echo ""
        else
            echo ""
        fi
        exec 4<&-  # 파일 디스크립터 닫기
        
        if [ -z "$password" ]; then
            echo "⊘ Skipped ${ip}"
            return 0
        fi
    else
        password="$common_password"
    fi

    echo "Deploying SSH key to ${user}@${ip} on port ${port}..."

    # 특수문자 처리를 위한 임시 패스워드 파일 생성
    local temp_pass_file
    temp_pass_file=$(mktemp)
    printf "%s" "$password" > "$temp_pass_file"
    chmod 600 "$temp_pass_file"
    
    # 먼저 SSH 연결 테스트
    if ! sshpass -f "$temp_pass_file" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -p "${port}" "${user}@${ip}" "echo 'Connection test successful'" >/dev/null 2>&1; then
        echo "✗ Failed to connect to ${ip} - Please check:" >&2
        echo "  - Password is correct" >&2
        echo "  - PasswordAuthentication is enabled in /etc/ssh/sshd_config" >&2
        echo "  - PermitRootLogin is enabled (if using root user)" >&2
        rm -f "$temp_pass_file"
        fail_count=$((fail_count + 1))
        failed_hosts="${failed_hosts}${ip}\n"
        return 0
    fi
    
    # sshpass를 사용하여 자동으로 패스워드 입력
    local deploy_output
    deploy_output=$(sshpass -f "$temp_pass_file" ssh-copy-id -o StrictHostKeyChecking=no -o ConnectTimeout=10 -p "${port}" "${user}@${ip}" 2>&1) || true
    
    # 출력 표시 (expr 에러 제외)
    echo "$deploy_output" | grep -v "^expr:" || true
    
    # 성공 여부 판단 (ssh-copy-id는 항상 0을 반환하므로 출력으로 판단)
    if echo "$deploy_output" | grep -qE "(Number of key\(s\) added|WARNING: All keys were skipped)"; then
        echo "✓ Successfully deployed to ${ip}"
        success_count=$((success_count + 1))
    else
        echo "✗ Failed to deploy to ${ip}" >&2
        fail_count=$((fail_count + 1))
        failed_hosts="${failed_hosts}${ip}\n"
    fi
    
    # 임시 파일 삭제
    rm -f "$temp_pass_file"
    return 0
}

# 각 호스트에 SSH 키 배포
for ip in "${host_array[@]}"; do
    # 빈 문자열이면 건너뜀
    [[ -z "$ip" ]] && continue
    
    deploy_to_host "$ip"
done

# 최종 결과 출력
echo "========================================"
echo "SSH key deployment completed!"
echo "Success: $success_count host(s)"
echo "Failed: $fail_count host(s)"

if [ $fail_count -gt 0 ]; then
    echo ""
    echo "Failed hosts:"
    echo -e "$failed_hosts"
    exit 1
fi

echo "All deployments successful!"
