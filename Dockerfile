FROM vbatts/slackware:current

ENV KERNEL_VER 4.19.16
ENV RSYNC_MIRROR ftp.nluug.nl::slackware/slackware64-current/
ENV SLACK_INITRD http://ftp.nluug.nl/pub/os/Linux/distr/slackware/slackware64-current/isolinux/initrd.img
ENV SPL_SBO https://slackbuilds.org/slackbuilds/14.2/system/spl-solaris.tar.gz
ENV SPL_SRC https://github.com/zfsonlinux/zfs/releases/download/zfs-0.7.12/spl-0.7.12.tar.gz
ENV ZFS_SBO https://slackbuilds.org/slackbuilds/14.2/system/zfs-on-linux.tar.gz
ENV ZFS_SRC https://github.com/zfsonlinux/zfs/releases/download/zfs-0.7.12/zfs-0.7.12.tar.gz
ENV ZFS_VER 0.7.12

# configure slackpkg to be non-interactive
RUN sed -i -e 's#^BATCH=off#BATCH=on#' \
    -e 's#^DIALOG=on#DIALOG=off#' \
    -e 's#^DEFAULT_ANSWER=n#DEFAULT_ANSWER=y#' \
# configure wget
    -e 's#^WGETFLAGS="--passive-ftp"#WGETFLAGS="--passive-ftp -nv"#' /etc/slackpkg/slackpkg.conf \
# configure mirror
  && sed -i -e 's%^http://%#http://%' \
    -e 's%#.*\(http://ftp\.nluug\.nl.*slackware64-current.*\)%\1%' /etc/slackpkg/mirrors \
# don't ask confirmation for slackware-current
  && mkdir -p /var/lib/slackpkg \
  && touch /var/lib/slackpkg/current

RUN slackpkg update \
  && slackpkg upgrade slackpkg \
  && slackpkg update \
  && slackpkg install \
     autoconf \
     automake \
     binutils \
     bison \
     ca-certificates \
     cdrtools \
     cmake \
     cpio \
     dev86 \
     doxygen \
     elfutils \
     flex \
     gc \
     gcc \
     gcc-g++ \
     gettext-tools \
     glibc \
     guile \
     intltool \
     kernel-headers \
     kernel-modules \
     kernel-source \
     kmod \
     libffi \
     libmpc \
     libtool \
     llvm \
     m4 \
     make \
     mkinitrd \
     patchelf \
     perl \
     pkg-config \
     rsync \
     strace \
     wget \
     xorriso \
     xz \
     zlib

# create all dirs we're going to use
RUN mkdir -p /tmp/{src/{spl,zfs},pkg,initrd}

# download and extract SBo files for SPL and ZFS
RUN wget -nv -O /tmp/src/spl.tar.gz ${SPL_SBO} \
  && wget -nv -O /tmp/src/zfs.tar.gz ${ZFS_SBO} \
  && tar xzf /tmp/src/spl.tar.gz --strip-components=1 -C /tmp/src/spl \
  && tar xzf /tmp/src/zfs.tar.gz --strip-components=1 -C /tmp/src/zfs \
  && wget -nv -O /tmp/src/spl/spl-${ZFS_VER}.tar.gz ${SPL_SRC} \
  && wget -nv -O /tmp/src/zfs/zfs-${ZFS_VER}.tar.gz ${ZFS_SRC}

# build and install SPL and ZFS packages
RUN export KERN="${KERNEL_VER}" \
  && export MAKEFLAGS="-j$(nproc)" \
  && cd /tmp/src/spl \
  && OUTPUT=/tmp/pkg sh ./spl-solaris.SlackBuild \
  && installpkg /tmp/pkg/spl-solaris-${ZFS_VER}_${KERNEL_VER}-x86_64-1_SBo.tgz \
  && cd /tmp/src/zfs \
  && OUTPUT=/tmp/pkg sh ./zfs-on-linux.SlackBuild

# mirror slack64 packages
RUN mkdir /tmp/iso \
  && rsync -av --delete -rlptD --delete-excluded --progress --exclude pasture --exclude testing --exclude source --exclude extra/source ${RSYNC_MIRROR} /tmp/iso

# download slackware64-current installer initrd and add the contents of the
# SPL and ZFS packages to create initrd-zfs.gz
RUN mkdir -p /tmp/initrd \
  && cd /tmp/initrd \
  && xzdec /tmp/iso/isolinux/initrd.img | cpio -idm \
  && installpkg --root /tmp/initrd /tmp/pkg/spl-solaris-${ZFS_VER}_${KERNEL_VER}-x86_64-1_SBo.tgz /tmp/pkg/zfs-on-linux-${ZFS_VER}_${KERNEL_VER}-x86_64-1_SBo.tgz \
  && depmod -b $(pwd) -a ${KERNEL_VER} \
# we use GZip instead of XZ or the initrd can't be unpacked (CRC issues, don't remember)
  && find . | cpio -o -H newc | gzip -9c > /tmp/iso/isolinux/initrd.img

RUN cp /tmp/pkg/*.tgz /tmp/iso/slackware64/a/ \
  && echo "zfs-on-linux:REC" >> /tmp/iso/slackware64/a/tagfile \
  && echo "spl-solaris:REC" >> /tmp/iso/slackware64/a/tagfile \
  && sort -o /tmp/iso/slackware64/a/tagfile /tmp/iso/slackware64/a/tagfile \
  && sed -i '/^"xz"/a "zfs-on-linux" "ZFS is a modern filesystem - REQUIRED" "on" \' /tmp/iso/slackware64/a/maketag \
  && sed -i '/^"smartmontools"/a "spl-solaris" "Solaris Porting Layer (SPL) - REQUIRED" "on" \' /tmp/iso/slackware64/a/maketag \
  && cp /tmp/iso/slackware64/a/maketag /tmp/iso/slackware64/a/maketag.ez

# Done: now run the following Docker commands in the directory that holds this Dockerfile
# $ docker volume create slack64_zfs
# $ docker build -t slack64_zfs:1.0 .
# $ docker run --volume slack64_zfs:/tmp --name slack64_zfs slack64_zfs:1.0
# Your custom Slackware installer is available in /var/lib/docker/volumes/slack64_zfs/_data/iso
# Make a GPT USB-stick with a single FAT32 partition, enable the 'esp' and 'boot' flags on
# said partition and copy the contents of /var/lib/docker/volumes/slack64_zfs/_data/iso
# to the USB-stick's root. It's now (U)EFI bootable.
