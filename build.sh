#!/bin/bash
#
# checkn1x build script
# https://asineth.gq/checkn1x
# Rebuilded by peterpt
# https://github.com/peterpt/checkn1x

VERSION="1.1.8 (X86)"
ROOTFS="https://github.com/peterpt/chkn1xrepo/raw/main/alpine-minirootfs-3.16.0-x86.tar.gz"
latest="https://assets.checkra.in/downloads/linux/cli/i486/77779d897bf06021824de50f08497a76878c6d9e35db7a9c82545506ceae217e/checkra1n"
prev1="https://github.com/peterpt/chkn1xrepo/raw/main/checkra1n0123"
prev2="https://github.com/peterpt/chkn1xrepo/raw/main/checkra1n0122"
prev3="https://github.com/peterpt/chkn1xrepo/raw/main/checkra1n0121"
prev4="https://github.com/peterpt/chkn1xrepo/raw/main/checkra1n012"
prev5="https://github.com/peterpt/chkn1xrepo/raw/main/checkra1n011"

# clean up previous attempts
umount -v work/rootfs/dev >/dev/null 2>&1
umount -v work/rootfs/sys >/dev/null 2>&1
umount -v work/rootfs/proc >/dev/null 2>&1
rm -rf work
mkdir -pv work/{rootfs,iso/boot/grub}
cd work

# fetch rootfs
curl -sL "$ROOTFS" | tar -xzC rootfs
mount -vo bind /dev rootfs/dev
mount -vt sysfs sysfs rootfs/sys
mount -vt proc proc rootfs/proc
cp /etc/resolv.conf rootfs/etc

cp rootfs/lib/libcrypto.so.1.1 rootfs/lib/libcrypto.so.3

cat << ! > rootfs/etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/v3.16/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
!

# rootfs packages & services

cat << ! | chroot rootfs /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin:/lib /bin/sh
apk update update && apk upgrade 
apk add alpine-base ncurses-terminfo-base libssl3
apk add udev openrc
apk add usbmuxd libusbmuxd-progs sshpass usbutils
apk add --no-scripts linux-lts linux-firmware-none
rc-update add bootmisc
rc-update add hwdrivers
rc-update add udev
rc-update add udev-trigger
rc-update add udev-settle
!

# kernel modules

cat << ! > rootfs/etc/mkinitfs/features.d/checkn1x.modules
kernel/drivers/usb/host
kernel/drivers/hid/usbhid
kernel/drivers/hid/hid-generic.ko
kernel/drivers/hid/hid-cherry.ko
kernel/drivers/hid/hid-apple.ko
kernel/net/ipv4
!

chroot rootfs /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin \
	/sbin/mkinitfs -F "checkn1x" -k -t /tmp -q $(ls rootfs/lib/modules)
rm -rfv rootfs/lib/modules >/dev/null 2>&1

mv -v rootfs/tmp/lib/modules rootfs/lib

#find rootfs/lib/modules/* -type f -name "*.ko" | xargs -n1 -P`nproc` -- strip -v --strip-unneeded
#find rootfs/lib/modules/* -type f -name "*.ko" | xargs -n1 -P`nproc` -- xz --x86 -v9eT0
depmod -b rootfs $(ls rootfs/lib/modules)

# unmount fs
umount -v rootfs/dev
umount -v rootfs/sys
umount -v rootfs/proc

# fetch resources
echo "Downloading Checkra1n Versions"
curl -Lo rootfs/usr/local/bin/checkra1n "$latest"
curl -Lo rootfs/usr/local/bin/checkra1n0123 "$prev1"
curl -Lo rootfs/usr/local/bin/checkra1n0122 "$prev2"
curl -Lo rootfs/usr/local/bin/checkra1n0121 "$prev3"
curl -Lo rootfs/usr/local/bin/checkra1n012 "$prev4"
curl -Lo rootfs/usr/local/bin/checkra1n011 "$prev5"

# copy files
cp -av ../inittab rootfs/etc
cp -av ../scripts/* rootfs/usr/local/bin/
chmod -v 755 rootfs/usr/local/bin/*
ln -sv sbin/init rootfs/init
ln -sv ../../etc/terminfo rootfs/usr/share/terminfo # fix ncurses

# boot config
cp -av rootfs/boot/vmlinuz-lts iso/boot/vmlinuz
cat << ! > iso/boot/grub/grub.cfg
insmod all_video
echo 'checkn1x $VERSION : https://asineth.gq'
linux /boot/vmlinuz quiet 
initrd /boot/initramfs.xz
boot
!

# initramfs
pushd rootfs
rm -rfv tmp/*
rm -rfv boot/*
rm -rfv var/cache/*
rm -fv etc/resolv.conf

find . | cpio -oH newc | xz -C crc32 --x86 -vz9eT0 > ../iso/boot/initramfs.xz
popd
# iso creation

grub-mkrescue -o "checkn1x-$VERSION.iso" iso --compress=xz
