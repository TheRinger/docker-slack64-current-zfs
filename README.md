# docker-slack64-current-zfs

Create a Slackware64-current installer with ZFS support and ZFS package included. This requires a [working Docker environment](https://docs.docker.com/install/).

## `git clone` this repo


```
export USB_DRIVE=/dev/sdj
export ZFS_VERSION=0.8.2
export KERN=5.4.14
git clone https://github.com/TheRinger/docker-slack64-current-zfs.git
cd docker-slack64-current-zfs
docker build -t slack64_zfs:1.0 .
docker volume create slack64_zfs
docker run --volume slack64_zfs:/tmp --name slack64_zfs --env ZFS_VER=${ZFS_VERSION} --env KERNEL_VER=${KERN} slack64_zfs:1.0
sh /files/installer/usbinstaller.sh ${USB_DRIVE}
```

Or grab the latest version of the ZFS SBo package and Slackware64-current kernel package in a one liner:

```
docker run --volume slack64_zfs:/tmp --name slack64_zfs --env ZFS_VER="$(wget -qO- https://slackbuilds.org/repository/14.2/system/zfs-on-linux/ | grep 'zfs-on-linux.*</h2>' | sed -e 's#.*(\(.*\)).*#\1#')" --env KERNEL_VER="$(wget -qO- https://ftp.nluug.nl/pub/os/Linux/distr/slackware/slackware64-current/kernels/VERSIONS.TXT | grep kernels | sed -e 's#^These kernels are version \(.*\)\.$#\1#')" slack64_zfs:1.0
```

## Create a USB-stick (UEFI)

When the container has done its job, all the files for the Slackware installer are in the container's data volume under `/tmp/iso`. This will most likely map to  `/var/lib/docker/volumes/slack64_zfs/_data/iso` on your host.

```
docker volume inspect --format '{{ .Mountpoint }}' slack64_zfs
```

To create a bootable USB-stick, get a stick of at least 4 GB and create a single GPT FAT32 partition on it. Then copy the contents of `/var/lib/docker/volumes/slack64_zfs/_data/iso` to the stick with the small script below.

**Modify the `USB_DEV` variable appropriately. Be careful, because this will destroy the data on the device configured in `${USB_DEV}`!**

```
USB_DEV=${"modifythis":-$USB_DEV} # change this
sgdisk -Z ${USB_DEV}
sgdisk -og ${USB_DEV}
sgdisk -N 1 -c 1:"SLACK64" -t 1:ef00 -A 1:set:2 ${USB_DEV}
mkfs.vfat -F32 -n SLACK64 ${USB_DEV}1

mount ${USB_DEV}1 /mnt/usb
rsync -rv --progress /var/lib/docker/volumes/slack64_zfs/_data/iso/ /mnt/usb
```

# Install Slack64-current on ZFS

The installer will have ZFS support and install the ZFS package. *You* will have to create the ZFS storage pools and modify several startup and shutdown scripts yourself to get Slackware up and running.

Follow the steps in `files/installer/INSTALL`. This file will also be included in the installer in `/zfs/INSTALL`.

# One liners

## Build everything for latest versions

```
_KERNELVER="$(wget -qO- https://ftp.nluug.nl/pub/os/Linux/distr/slackware/slackware64-current/kernels/VERSIONS.TXT | grep kernels | sed -e 's#^These kernels are version \(.*\)\.$#\1#')"
_ZFSVER="$(wget -qO- https://slackbuilds.org/repository/14.2/system/zfs-on-linux/ | grep 'zfs-on-linux.*</h2>' | sed -e 's#.*(\(.*\)).*#\1#')"
if [ -n "${_KERNELVER}" -a -n "${_ZFSVER}" ]
then
  docker build -t slack64_zfs:${_KERNELVER}_${_ZFSVER} . && \
  docker volume create slack64_zfs && \
  docker run --rm --volume slack64_zfs:/tmp --name slack64_zfs --env ZFS_VER=${_ZFSVER} --env KERNEL_VER=${_KERNELVER} slack64_zfs:${_KERNELVER}_${_ZFSVER} && \
  docker volume inspect --format '{{ .Mountpoint }}' slack64_zfs
fi
```
