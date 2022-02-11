#!/bin/bash

NHOSTNAME="example01"
DISKONE="vda"
DISKTWO="vdb"
NETWORK_IFACE="enp1s0"

# important: set pipefile bash option, see bash manual
set -o pipefail
set -e
set -E

# LANG=C chroot /mnt /bin/bash

echo "setting hostname to ${NHOSTNAME} .."
echo "${NHOSTNAME}" > /etc/hostname

echo "creating efi location for both disks .."
mkdir -p "/mnt/boot/grub-efi-${DISKONE}/EFI/grub-efi-${DISKONE}"
mkdir -p "/mnt/boot/grub-efi-${DISKTWO}/EFI/grub-efi-${DISKTWO}"

echo "install base packages .."
apt-get update
apt-get -y install grub2-common grub-efi vim cryptsetup lvm2 mdadm vim tree xz-utils xfsprogs sudo arch-install-scripts
echo "GRUB_ENABLE_CRYPTODISK=y" > /etc/default/grub.d/local.cfg

echo "installing kernel .."
apt-get -y install linux-image-amd64

update-initramfs -u

echo "changing update-grub scripts to reflect two disk setup .."

echo "creating backup copy of update-grub .."
cp /usr/sbin/update-grub{,.bak}

echo "adding dpkg revert for update-grub scripts to not overwrite our changes .."
dpkg-divert --add --rename --divert /usr/sbin/update-grub.orig /usr/sbin/update-grub
dpkg-divert --add --rename --divert /usr/sbin/update-grub2.orig /usr/sbin/update-grub2

echo "creating new script .."
cat > /usr/sbin/update-grub-efi << EOF
#!/bin/sh
set -e
grub-mkconfig -o /boot/grub/grub.cfg "$@"
grub-mkstandalone --directory /usr/lib/grub/x86_64-efi --output /boot/grub-efi-${DISKONE}/EFI/grub-efi-${DISKONE}/grubx64.efi --format x86_64-efi --compress=xz --themes='' /boot/grub/grub.cfg
grub-mkstandalone --directory /usr/lib/grub/x86_64-efi --output /boot/grub-efi-${DISKTWO}/EFI/grub-efi-${DISKTWO}/grubx64.efi --format x86_64-efi --compress=xz --themes='' /boot/grub/grub.cfg
EOF

chmod +x /usr/sbin/update-grub-efi
ln -sf /usr/sbin/update-grub-efi /usr/sbin/update-grub
ln -sf /usr/sbin/update-grub-efi /usr/sbin/update-grub2

echo "updating grub .."
update-grub

echo "adding EFI boot entries with efibootmgr .."
efibootmgr -c -d "/dev/${DISKONE}" -p 1 -w -L "wratvirt01 GRUB EFI (/dev/${DISKONE})" -l "/EFI/grub-efi-${DISKONE}/grubx64.efi"
efibootmgr -c -d "/dev/${DISKTWO}" -p 1 -w -L "wratvirt01 GRUB EFI (/dev/${DISKTWO})" -l "/EFI/grub-efi-${DISKTWO}/grubx64.efi"

echo "installing and enable ssh server .."
apt-get -y install openssh-server
systemctl enable ssh

echo "setting root password, you will be asked for the root password twice .."
passwd

echo "installing additional packages .."
DEBIAN_FRONTEND='noninteractive' apt-get -y --no-install-recommends install lsb-release ntpdate bzip2 less sudo htop net-tools parted passwd screen sed tar tcpdump telnet util-linux zip wget smartmontools ethtool tmux

echo "creating automation user .."
useradd -m -g users -G sudo -s /bin/bash automation

# echo "setting password for automation user, you will be asked for the password twice .."
# passwd automation

mkdir -p /home/automation/.ssh
cat > /home/automation/.ssh/authorized_keys << EOF
ssh-ed25519 AAAAC3N somekey
EOF

chown -R automation: /home/automation/.ssh
chmod 700 /home/automation/.ssh
chmod 600 /home/automation/.ssh/authorized_keys

echo "enabling passwordless sudo for automation user .."
cat > /etc/sudoers.d/automation-all-without-password << EOF
## Allow automation user to execute any command without password
automation ALL=(ALL) NOPASSWD: ALL
EOF

DEBIAN_FRONTEND='noninteractive' apt-get -y install busybox dropbear
sed -i 's/^#DROPBEAR_OPTIONS=$/DROPBEAR_OPTIONS="-I 180 -j -k -p 2222 -s"/' /etc/dropbear-initramfs/config

cat > /etc/dropbear-initramfs/authorized_keys << EOF
ssh-ed25519 AAAAC3N somekey
EOF
chmod 400 /etc/dropbear-initramfs/authorized_keys
update-initramfs -u

cat > /etc/network/interfaces.d/${NETWORK_IFACE}  << EOF
auto ${NETWORK_IFACE}
allow-hotplug ${NETWORK_IFACE}
iface ${NETWORK_IFACE} inet dhcp
EOF

echo "chroot tasks done."
