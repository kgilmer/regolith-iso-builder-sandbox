#!/bin/bash

set -e
set -o errexit

TARGET_DIR=$1

if [ -z $TARGET_DIR ]; then
    TARGET_DIR="./"
fi
    

TIMESTAMP=$(date +%s)
CHROOT="$TARGET_DIR/image-root-$TIMESTAMP"
IMAGE_NAME=regolith-3_3-trixie-$TIMESTAMP.img

if [ -d $CHROOT ]; then
    echo "$CHROOT dir already exists. Aborting."
    exit 1
fi

debootstrap --arch=amd64 --variant=minbase trixie $CHROOT

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

debootstick "$CHROOT" "$TARGET_DIR/$IMAGE_NAME"

echo "$TARGET_DIR/$IMAGE_NAME is ready to boot"