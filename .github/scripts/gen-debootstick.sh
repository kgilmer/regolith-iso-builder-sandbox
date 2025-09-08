#!/bin/bash

set -e
set -o errexit

TARGET_DIR=$1
RELEASE_LABEL=$2

if [ -z $TARGET_DIR ]; then
    TARGET_DIR="./"
fi

if [ -z $RELEASE_LABEL ]; then
    RELEASE_LABEL=$(date +%s)
fi

CHROOT="$TARGET_DIR/image-root-$RELEASE_LABEL"
IMAGE_NAME=regolith-3_3-trixie-$RELEASE_LABEL.img

if [ -d $CHROOT ]; then
    echo "$CHROOT dir already exists. Aborting."
    exit 1
fi

debootstrap \
    --arch=amd64 \
    --variant=minbase \
    --include=kbd,locales,gpg,systemd,wget,whiptail \
    --components=main,contrib,non-free,non-free-firmware \
    trixie \
    $CHROOT

# Temporary, package these files (TODO)
cp ./interactive-setup.sh $CHROOT/usr/bin/
cp ./interactive-setup.service $CHROOT/etc/systemd/system

# Mount required filesystems
mount -t proc /proc $CHROOT/proc
mount --rbind /sys  $CHROOT/sys
mount --make-rslave $CHROOT/sys
mount --rbind /dev  $CHROOT/dev
mount --make-rslave $CHROOT/dev
mount -t devpts devpts $CHROOT/dev/pts

# Enter the chroot
echo "root:boot" | chroot $CHROOT chpasswd
cp gen-debootstick-rootfs.sh $CHROOT
chroot $CHROOT ./gen-debootstick-rootfs.sh

# Cleanup after exit
rm $CHROOT/gen-debootstick-rootfs.sh
umount -l $CHROOT/proc || true
umount -l $CHROOT/sys || true
umount -l $CHROOT/dev/pts || true
umount -l $CHROOT/dev || true

debootstick \
    --disk-layout disk-layout.txt \
    "$CHROOT" \
    "$TARGET_DIR/$IMAGE_NAME"

echo "$TARGET_DIR/$IMAGE_NAME is ready to boot"