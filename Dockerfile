FROM vbatts/slackware:current

ENV RSYNC_MIRROR ftp.nluug.nl::slackware/slackware64-current/

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
  && mkdir -p /tmp/{src/{spl,zfs},pkg,initrd,iso}

# install packages required for building ZFS and SPL packages
RUN slackpkg update \
  && slackpkg upgrade slackpkg \
  && slackpkg update \
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

# mirror slack64 packages and setup initrd
RUN rsync -av --delete -rlptD --delete-excluded --progress --exclude pasture --exclude testing --exclude source --exclude extra/source ${RSYNC_MIRROR} /tmp/iso

# setup initrd
RUN cd /tmp/initrd \
  && xzdec /tmp/iso/isolinux/initrd.img | cpio -i -d -H newc --no-absolute-filenames

# add build script
COPY build_zfs.sh /build_zfs.sh
COPY grub-zfs.cfg /grub.cfg
RUN chmod +x /build_zfs.sh

CMD [ "/bin/sh", "-c", "/build_zfs.sh" ]
