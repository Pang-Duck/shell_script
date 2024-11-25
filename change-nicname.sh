#!/bin/bash
#### Change NIC Name ####
NIC_NAME="ens192"
MAC_ADDRESS=$(ip link show | awk '/ether/ {print $2; exit}')
NIC_YAML_NAME=""

function debian_nic_change() {
    grub2-mkconfig -o /boot/grub2/grub.cfg
}

function rhel_nic_change() {}
echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$MAC_ADDRESS\", NAME=\"$NIC_NAME\"" >/etc/udev/rules.d/70-persistent-net.rules

update-grub

touch /var/lib/cloud/reboot_flag

rm -rf /etc/sysconfig/network-scripts/ifcfg-eth0

reboot
