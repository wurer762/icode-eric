#!/bin/bash
# baseline.sh - the same baseline, "the old way"
apt-get update
apt-get install -y htop curl vim git qemu-guest-agent
systemctl enable --now qemu-guest-agent
timedatectl set-timezone Europe/Luxembourg
echo "This server is managed by a script." >> /etc/motd
groupadd admins
useradd -m -s /bin/bash -c "Carol Admin" -G admins carol
echo "%admins ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/admins
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart ssh
echo "Done."
