#!/bin/bash
set -o
set -x

RSYNC_MIRROR="ftp.nluug.nl::slackware/slackware64-current/"
ZFS_SBO="https://slackbuilds.org/slackbuilds/14.2/system/zfs-on-linux.tar.gz"
ZFS_URL="https://github.com/zfsonlinux/zfs/releases/download/"

# download and extract SBo files for SPL and ZFS
wget -nv -O /tmp/src/zfs.tar.gz ${ZFS_SBO}
tar xzf /tmp/src/zfs.tar.gz --strip-components=1 -C /tmp/src/zfs
wget -nv -O /tmp/src/zfs/zfs-${ZFS_VER}.tar.gz ${ZFS_URL}/zfs-${ZFS_VER}/zfs-${ZFS_VER}.tar.gz

# build and install ZFS packages
export KERN="${KERNEL_VER}"
export MAKEFLAGS="-j$(nproc)"
cd /tmp/src/zfs
OUTPUT=/tmp/pkg sh ./zfs-on-linux.SlackBuild

# add the contents of ZFS packages to create initrd.img.zfs
cd /tmp/initrd
installpkg --root /tmp/initrd /tmp/pkg/zfs-on-linux-${ZFS_VER}_${KERNEL_VER}-x86_64-1_SBo.tgz
depmod -b $(pwd) -a ${KERNEL_VER}
find . | cpio -o -H newc | xz -z --check=crc32 -T0 > /tmp/iso/isolinux/initrd.img.zfs

# add ZFS packages to installer as well, include them in "a" tagfile
cp /tmp/pkg/*.tgz /tmp/iso/slackware64/a/
echo "zfs-on-linux:REC" >> /tmp/iso/slackware64/a/tagfile
sort -o /tmp/iso/slackware64/a/tagfile /tmp/iso/slackware64/a/tagfile
sed -i '/^"xz"/a "zfs-on-linux" "ZFS is a modern filesystem - REQUIRED" "on" \' /tmp/iso/slackware64/a/maketag
cp /tmp/iso/slackware64/a/maketag /tmp/iso/slackware64/a/maketag.ez

# copy modified GRUB config
cp /grub.cfg /tmp/iso/EFI/BOOT/grub.cfg

cat << EOF
Slackware64-current installer with ZFS v${ZFS_VER} on Linux v${KERNEL_VER} built.
The entire installer is in this container's data volume under /tmp/iso,
most likely in /var/lib/docker/volumes/slack64_zfs/_data/iso .

To create a bootable USB-stick, get a stick of at least $(du -hs /tmp/iso | cut -f1)
and create a single GPT FAT32 partition on it. Then copy the contents of
/var/lib/docker/volumes/slack64_zfs/_data/iso to the stick.

USB_DEV="/dev/changeMeToTheCorrectDeviceName" # change this
sgdisk -Z \${USB_DEV} && \
sgdisk -og \${USB_DEV} && \
sgdisk -N 1 -c 1:"SLACK64" -t 1:ef00 -A 1:set:2 \${USB_DEV} && \
mkfs.vfat -F32 -n SLACK64 \${USB_DEV}1 && \

mount \${USB_DEV}1 /mnt/usb && \
rsync -rv --progress /var/lib/docker/volumes/slack64_zfs/_data/iso/ /mnt/usb
EOF
