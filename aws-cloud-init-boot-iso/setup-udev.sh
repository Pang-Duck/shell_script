#!/bin/bash
#### Change NIC Name ####

if [ -f "/var/lib/cloud/reboot_flag" ]; then
    exit 0
fi
MAC_ADDRESS=$(ip link show | awk '/ether/ {print $2; exit}')

echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$MAC_ADDRESS\", NAME=\"ens192\"" >/etc/udev/rules.d/70-persistent-net.rules

udevadm control --reload-rules
udevadm trigger

touch /var/lib/cloud/reboot_flag

rm -rf /etc/sysconfig/network-scripts/ifcfg-eth0
reboot
