# debootstrap

Automatic setup of Debian.

## Repair failed device

### Legacy Boot Mode

In Legacy Boot Mode there are two RAID1 arrays.

* Copy the partition table to the new disk:
```
sgdisk /dev/<remaining_disk> -R /dev/<newdisk>"
sgdisk -G /dev/<newdisk>
```
* Add the new partitions to the arrays:
```
mdadm --manage /dev/md/boot -a /dev/<newdisk>1
mdadm --manage /dev/md/lvm -a /dev/<newdisk>2
```

### UEFI

In UEFI mode there are two RAID1 arrays and every disk has a seperate EFI partition (sda1).

* Copy the partition table to the new disk:
```
sgdisk /dev/<remaining_disk> -R /dev/<newdisk>"
sgdisk -G /dev/<newdisk>
```
* Create a vfat filesystem on the first partition for EFI
```
mkfs.fat -F32 -n "EFI" "/dev/<newdisk>1"
```
* Add the new partitions to the arrays:
```
mdadm --manage /dev/md/boot -a /dev/<newdisk>2
mdadm --manage /dev/md/lvm -a /dev/<newdisk>3
```
* Get the blkid of the new EFI partition:
```
lsblk -o UUID /dev/<newdisk>1
```
* Change the UUID of the mount point in _/etc/fstab_
* Run update-grub
* Add the new disk to the EFI boot order:
```
efibootmgr -c -d "/dev/<newdisk>" -p 1 -w -L "GRUB EFI (/dev/<newdisk>)" -l "/EFI/grub-efi-<newdisk>/grubx64.efi"
```

## Sources

* https://gist.github.com/ppmathis/ccfbfce86484dc61834c1f17568d7b80
* https://bisco.org/notes/installing-debian-with-encrypted-boot-using-grml/
* http://www.coredump.us/index.php?n=Main.DebianEncryptedDebootstrap
* https://devconnected.com/how-to-encrypt-root-filesystem-on-linux/
* https://github.com/nilsmeyer/ansible-debootstrap