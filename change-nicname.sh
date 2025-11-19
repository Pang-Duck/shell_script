#!/bin/bash
#### Change NIC Name(execute only root), 인터페이스 YAML은 수동으로 변경 필요####
NIC_NAME="ens192"
MAC_ADDRESS=$(ip link show | awk '/ether/ {print $2; exit}')
#NIC_FILE_NAME_RHEL=""
#NIC_FILE_NAME_DEBIAN=""
OS_SYSTEM="cat /etc/os-release | grep -iw 'ID' | tr -d '[:punct:] ID' | head -n 1"

function debian_nic_change() {
    echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$MAC_ADDRESS\", NAME=\"$NIC_NAME\"" >/etc/udev/rules.d/70-persistent-net.rules
    update-grub
}

function rhel_nic_change() {
    echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$MAC_ADDRESS\", NAME=\"$NIC_NAME\"" >/etc/udev/rules.d/70-persistent-net.rules
    grub2-mkconfig -o /boot/grub2/grub.cfg

}

function modify_grub() {
    GRUB_CONFIG="/etc/default/grub"

    NEW_CMD="net.ifnames=0 biosdevname=0"

    if grep -q '^GRUB_CMDLINE_LINUX=' "$GRUB_CONFIG"; then
        CURRENT_CMD=$(grep '^GRUB_CMDLINE_LINUX=' "$GRUB_CONFIG" | cut -d'"' -f2)

        if [[ "$CURRENT_CMD" != *"net.ifnames=0"* || "$CURRENT_CMD" != *"biosdevname=0"* ]]; then
            if [[ -z "$CURRENT_CMD" ]]; then
                UPDATED_CMD="$NEW_CMD"
            else
                UPDATED_CMD="$CURRENT_CMD $NEW_CMD"
            fi

            =
            sed -i "s|^GRUB_CMDLINE_LINUX=\".*\"|GRUB_CMDLINE_LINUX=\"$UPDATED_CMD\"|" "$GRUB_CONFIG"
        fi
    else

        echo "GRUB_CMDLINE_LINUX=\"$NEW_CMD\"" >>"$GRUB_CONFIG"
    fi
}

#### Main ####
modify_grub

if [[ "$OS_SYSTEM" == "rocky" ]] || [[ "$OS_SYSTEM" == "rhel" ]]; then
    rhel_nic_change
elif [[ "$OS_SYSTEM" == "ubuntu" ]] || [[ "$OS_SYSTEM" == "debian" ]]; then
    debian_nic_change
fi

reboot
