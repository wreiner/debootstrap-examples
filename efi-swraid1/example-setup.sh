#!/bin/bash

NHOSTNAME="example01"
DISKONE="vda"
DISKTWO="vdb"

# important: set pipefile bash option, see bash manual
set -o pipefail
set -e
set -E

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

hostnamectl set-hostname "${NHOSTNAME}"

## -- PARTITIONING

echo "zapping partition table of disk one"
sgdisk -Z "/dev/${DISKONE}"

# create partitions with type EFI and raid
echo "creating partitions on disk one .."
sgdisk "/dev/${DISKONE}" --new 0:+1M:+512M --typecode 0:ef00
sgdisk "/dev/${DISKONE}" --new 0:0:+512M --typecode 0:fd00
sgdisk "/dev/${DISKONE}" --new 0:0:0 --typecode 0:fd00

echo "zapping partition table of disk two"
sgdisk -Z "/dev/${DISKTWO}"

# create partitions with type EFI raid
echo "creating partitions on disk two .."
sgdisk "/dev/${DISKTWO}" --new 0:+1M:+512M --typecode 0:ef00
sgdisk "/dev/${DISKTWO}" --new 0:0:+512M --typecode 0:fd00
sgdisk "/dev/${DISKTWO}" --new 0:0:0 --typecode 0:fd00

## -- RAID SETUP

echo "creating raid arrays .."
mdadm --create --verbose --level=1 --metadata=1.2 --raid-devices=2 /dev/md/boot "/dev/${DISKONE}2" "/dev/${DISKTWO}2"
mdadm --create --verbose --level=1 --metadata=1.2 --raid-devices=2 /dev/md/lvm "/dev/${DISKONE}3" "/dev/${DISKTWO}3"

## -- ENCRYPTION

echo "encrypting disk, you will be asked for YES and your encryption key twice .."
cryptsetup -y -v luksFormat --type luks1 /dev/md/lvm
echo "unlocking encrypted disk, you will be asked for your encryption key once .."
cryptsetup open /dev/md/lvm cryptlvm

## -- LVM

echo "creating LVM structure .."
pvcreate /dev/mapper/cryptlvm
vgcreate root_vg /dev/mapper/cryptlvm
lvcreate -n root_lv -L 4G root_vg
lvcreate -n var_lv -L 3G root_vg
lvcreate -n tmp_lv -L 1G root_vg

## -- FILESYSTEMS

echo "creating filesystems with force .."
mkfs.xfs -f /dev/mapper/root_vg-root_lv
mkfs.xfs -f /dev/mapper/root_vg-tmp_lv
mkfs.xfs -f /dev/mapper/root_vg-var_lv
mkfs.fat -F32 -n "EFI" "/dev/${DISKONE}1"
mkfs.fat -F32 -n "EFI" "/dev/${DISKTWO}1"
mkfs.ext4 -F /dev/md/boot

## -- MOUNTS

echo "preparing mount points and mounting filesystems .."
mount /dev/root_vg/root_lv /mnt
mkdir -p /mnt/{boot,tmp,var}
mount /dev/root_vg/tmp_lv /mnt/tmp
mount /dev/root_vg/var_lv /mnt/var

mount /dev/md/boot /mnt/boot

mkdir -p "/mnt/boot/grub-efi-${DISKONE}"
mount "/dev/${DISKONE}1" "/mnt/boot/grub-efi-${DISKONE}"
mkdir -p "/mnt/boot/grub-efi-${DISKONE}/EFI/grub-efi-${DISKONE}"

mkdir -p "/mnt/boot/grub-efi-${DISKTWO}"
mount "/dev/${DISKTWO}1" "/mnt/boot/grub-efi-${DISKTWO}"
mkdir -p "/mnt/boot/grub-efi-${DISKTWO}/EFI/grub-efi-${DISKTWO}"

echo "fixing /tmp permissions .."
# https://superuser.com/a/1541135
chmod 1777 /mnt/tmp

## -- DEBIAN INSTALL

echo "starting bootstrap of Debian .."
debootstrap --arch amd64 bullseye /mnt

echo "generating fstab in new chroot environment .."
apt-get update
apt-get install arch-install-scripts
genfstab -U -p /mnt | sed 's/rw,relatime,data=ordered/defaults,relatime/' >> /mnt/etc/fstab

echo "adding cryptdevice to crypttab .."
echo cryptlvm UUID=$(blkid -s UUID -o value /dev/md/lvm) none luks,discard,initramfs >> /mnt/etc/crypttab

## -- PREPARE CHROOT

echo "preparing chroot environment .."

mount -t proc none /mnt/proc
mount -t tmpfs none /mnt/tmp
mount -o bind /dev /mnt/dev
mount -o bind /sys /mnt/sys
mount -t devpts /dev/pts /mnt/dev/pts
mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars

echo "setting hostname in chroot environment .."
echo "${NHOSTNAME}" > /mnt/etc/hostname

echo "enabling contrib,non-free for apt in chroot environment .."
sed -i '/^\([^#].*main\)*$/s/main/& contrib non-free/' /mnt/etc/apt/sources.list

echo
echo "to start chroot run:"
echo "LANG=C chroot /mnt /bin/bash"

echo
echo "Copy gh-chroot.sh to /mnt/root and run it inside the chroot to initiale configure the system."

echo
echo "Do not forget to configure network settings in /etc/initramfsconf"
