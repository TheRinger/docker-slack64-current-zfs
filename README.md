# docker-slack64-current-zfs

Create a Slackware64-current installer with ZFS support and ZFS and SPL packages included.

## Build the image

This step creates a Slackware64-current environment to build the ZFS and SPL packages.

```
docker build -t slack64_zfs:1.0 .
```

## Run the container with a volume

This step creates a volume to hold the useful files. Then it runs the image in a container to create the new Slack64 installer image.

```
docker volume create slack64_zfs
docker run --volume slack64_zfs:/tmp --name slack64_zfs --env ZFS_VER=0.7.12 --env KERNEL_VER=4.19.17 slack64_zfs:1.0
```

Or with "dynamic" ZFS and kernel versions

```
docker run --volume slack64_zfs:/tmp --name slack64_zfs --env ZFS_VER="$(wget -qO- https://slackbuilds.org/repository/14.2/system/zfs-on-linux/ | grep 'zfs-on-linux.*</h2>' | sed -e 's#.*(\(.*\)).*#\1#')" --env KERNEL_VER="$(wget -qO- https://ftp.nluug.nl/pub/os/Linux/distr/slackware/slackware64-current/kernels/VERSIONS.TXT | grep kernels | sed -e 's#^These kernels are version \(.*\)\.$#\1#')" slack64_zfs:1.0
```

## Create a USB-stick (UEFI)

The entire installer is in this container's data volume under `/tmp/iso`, most likely in `/var/lib/docker/volumes/slack64_zfs/_data/iso`.

To create a bootable USB-stick, get a stick of at least 4 GB and create a single GPT FAT32 partition on it. Then copy the contents of `/var/lib/docker/volumes/slack64_zfs/_data/iso` to the stick.

```
USB_DEV="/dev/changeMeToTheCorrectDeviceName" # change this
sgdisk -Z ${USB_DEV}
sgdisk -og ${USB_DEV}
sgdisk -N 1 -c 1:"SLACK64" -t 1:ef00 -A 1:set:2 ${USB_DEV}
mkfs.vfat -F32 -n SLACK64 ${USB_DEV}1

mount ${USB_DEV}1 /mnt/usb
rsync -rv --progress /var/lib/docker/volumes/slack64_zfs/_data/iso/ /mnt/usb
```

# Install Slack64-current on ZFS

The installer will have ZFS support and install the ZFS and SPL packages. *You* will have to create the ZFS storage pools and modify several startup and shutdown scripts yourself to get Slackware up and running. See the (rather dated) [ZFS root guide on SlackWiki](https://www.slackwiki.com/ZFS_root) for more info.
