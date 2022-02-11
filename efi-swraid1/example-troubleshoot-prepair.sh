#!/bin/bash

NHOSTNAME="example01"
DISKONE="vda"
DISKTWO="vdb"

hostnamectl set-hostname "${NHOSTNAME}"

mdadm --assemble /dev/md/boot
mdadm --assemble /dev/md/lvm

cryptsetup open /dev/md/lvm cryptlvm

vgchange -ay

mount /dev/root_vg/root_lv /mnt
mount /dev/root_vg/var_lv /mnt/var
mount /dev/root_vg/tmp_lv /mnt/tmp
mount /dev/md/boot /mnt/boot
mount "/dev/${DISKONE}1" "/mnt/boot/grub-efi-${DISKONE}"
mount "/dev/${DISKTWO}1" "/mnt/boot/grub-efi-${DISKTWO}"

echo "Get ready for chroot"
mount -t proc none /mnt/proc
mount -t tmpfs none /mnt/tmp
mount -o bind /dev /mnt/dev
mount -o bind /sys /mnt/sys
mount -t devpts /dev/pts /mnt/dev/pts
mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars

echo
echo "to start chroot run:"
echo "LANG=C chroot /mnt /bin/bash"
