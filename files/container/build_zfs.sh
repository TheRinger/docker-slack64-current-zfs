#!/bin/bash
set -o
set -x

RSYNC_MIRROR="ftp.nluug.nl::slackware/slackware64-current/"
SPL_SBO="https://slackbuilds.org/slackbuilds/14.2/system/spl-solaris.tar.gz"
ZFS_SBO="https://slackbuilds.org/slackbuilds/14.2/system/zfs-on-linux.tar.gz"
ZFS_URL="https://github.com/zfsonlinux/zfs/releases/download/"

# download and extract SBo files for SPL and ZFS
wget -nv -O /tmp/src/spl.tar.gz ${SPL_SBO}
wget -nv -O /tmp/src/zfs.tar.gz ${ZFS_SBO}
tar xzf /tmp/src/spl.tar.gz --strip-components=1 -C /tmp/src/spl
tar xzf /tmp/src/zfs.tar.gz --strip-components=1 -C /tmp/src/zfs
wget -nv -O /tmp/src/spl/spl-${ZFS_VER}.tar.gz ${ZFS_URL}/zfs-${ZFS_VER}/spl-${ZFS_VER}.tar.gz
wget -nv -O /tmp/src/zfs/zfs-${ZFS_VER}.tar.gz ${ZFS_URL}/zfs-${ZFS_VER}/zfs-${ZFS_VER}.tar.gz

# build and install SPL and ZFS packages
export KERN="${KERNEL_VER}"
export MAKEFLAGS="-j$(nproc)"
cd /tmp/src/spl
OUTPUT=/tmp/pkg sh ./spl-solaris.SlackBuild
installpkg /tmp/pkg/spl-solaris-${ZFS_VER}_${KERNEL_VER}-x86_64-1_SBo.tgz
cd /tmp/src/zfs
OUTPUT=/tmp/pkg sh ./zfs-on-linux.SlackBuild

# add the contents of the SPL and ZFS packages to create initrd.img.zfs
cd /tmp/initrd
installpkg --root /tmp/initrd /tmp/pkg/spl-solaris-${ZFS_VER}_${KERNEL_VER}-x86_64-1_SBo.tgz /tmp/pkg/zfs-on-linux-${ZFS_VER}_${KERNEL_VER}-x86_64-1_SBo.tgz
depmod -b $(pwd) -a ${KERNEL_VER}
find . | cpio -o -H newc | xz -z --check=crc32 -T0 > /tmp/iso/isolinux/initrd.img.zfs

# add SPL and ZFS packages to installer as well, include them in "a" tagfile
cp /tmp/pkg/*.tgz /tmp/iso/slackware64/a/
echo "zfs-on-linux:REC" >> /tmp/iso/slackware64/a/tagfile
echo "spl-solaris:REC" >> /tmp/iso/slackware64/a/tagfile
sort -o /tmp/iso/slackware64/a/tagfile /tmp/iso/slackware64/a/tagfile
sed -i '/^"xz"/a "zfs-on-linux" "ZFS is a modern filesystem - REQUIRED" "on" \' /tmp/iso/slackware64/a/maketag
sed -i '/^"smartmontools"/a "spl-solaris" "Solaris Porting Layer (SPL) - REQUIRED" "on" \' /tmp/iso/slackware64/a/maketag
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
