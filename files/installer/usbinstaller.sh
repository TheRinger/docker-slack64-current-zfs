#!/bin/bash

if [[ -z $1 ]];then 
  echo "Pass the drive as the first argument ie.. /dev/sdf"
fi

USB_DEV=$1
sgdisk -Z $USB_DEV
sgdisk -og $USB_DEV
sgdisk -N 1 -c 1:"SLACK64" -t 1:ef00 -A 1:set:2 $USB_DEV && sync
mkfs.vfat -F32 -n SLACK64 ${USB_DEV}1 && sync

mount ${USB_DEV}1 /mnt/usb2 && sync
rsync -rv --progress /var/lib/docker/volumes/slack64_zfs/_data/iso/ /mnt/usb2 && sync
umount /mnt/usb2
eject $1
