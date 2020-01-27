FROM vbatts/slackware:current

ENV RSYNC_MIRROR 10.0.0.33::Slackware/mirrors/slackware/slackware64-current/

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
  && touch /var/lib/slackpkg/current \
# create all dirs we're going to use
  && mkdir -p /tmp/{src/zfs,pkg,initrd,iso/zfs}

# install packages required for building ZFS package
RUN slackpkg update \
  && slackpkg upgrade slackpkg \
  && slackpkg update \
  # install dependency of new version of wget first
  && slackpkg install libpsl pcre2 \
  && slackpkg upgrade-all \
  && slackpkg install \
     autoconf \
     automake \
     bash \
     binutils \
     bison \
     ca-certificates \
     cdrtools \
     cmake \
     cpio \
     dcron \
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
     libpsl \
     libtool \
     llvm \
     m4 \
     make \
     mkinitrd \
     patchelf \
     pcre \
     pcre2 \
     perl \
     pkg-config \
     rsync \
     strace \
     wget \
     xorriso \
     xz \
     zlib

RUN /usr/sbin/update-ca-certificates --fresh

# mirror slack64 packages and setup initrd
RUN rsync -av --delete -rlptD --delete-excluded --progress --exclude pasture --exclude testing --exclude source --exclude extra/source ${RSYNC_MIRROR} /tmp/iso

# setup initrd
RUN cd /tmp/initrd \
  && xzdec /tmp/iso/isolinux/initrd.img | cpio -i -d -H newc --no-absolute-filenames

# add build script
COPY files/container/build_zfs.sh /build_zfs.sh
COPY files/container/grub-zfs.cfg /grub.cfg
RUN chmod +x /build_zfs.sh

# add installer files
COPY files/installer/INSTALL /tmp/iso/zfs/INSTALL
COPY files/installer/init.zfs.patch /tmp/iso/zfs/init.zfs.patch
COPY files/installer/rc.S.zfs.patch /tmp/iso/zfs/rc.S.zfs.patch

CMD [ "/bin/sh", "-c", "/build_zfs.sh" ]
