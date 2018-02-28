#!/bin/bash
#
# Create an rsync backup / snapshot of root volume filesystems
#
# T.McGinnis 2/2018
#
# version 0.1
#
RECOVERYSOURCE=/mnt/bootrecovery/root
RECOVERYDEST=/mnt/sysimage

BOOTDEVICE="sda"
BOOTPART=$BOOTDEVICE"1"

if [ "$1" = "-u" ]; then
   mount|awk '{print $3}' | grep "^$RECOVERYDEST" | sort -r | xargs -l1 umount >/dev/null 2>&1
   exit
fi

ROOTLV=`grep -w "/" /etc/fstab|awk '{print $1}'`
echo "ROOTLV:$ROOTLV"
if [ "${ROOTLV/\/dev\/mapper\/}" != "$ROOTLV" ]; then
   ROOTVG="${ROOTLV/\/dev\/mapper\/}"
   ROOTVG="${ROOTVG/-*}"
else
   ROOTVG="${ROOTLV/\/dev\/}"
   ROOTVG="${ROOTVG/\/*}"
fi
echo "Root Volmume Group: $ROOTVG"

BOOTMOUNTEDON=`mount|grep -w "^/dev/$BOOTPART"|awk '{print $3}'|grep -v $RECOVERYDEST`
echo "BOOTMOUNTEDON:$BOOTMOUNTEDON"
ROOTMOUNTEDON=`mount|grep -w "^$ROOTLV"|awk '{print $3}'|grep -v $RECOVERYDEST`
if [ "$BOOTMOUNTEDON" ]; then
   echo ""
   echo "$BOOTPART is already mounted on \"$BOOTMOUNTEDON\"."
fi
if [ "$ROOTMOUNTEDON" ]; then
   echo ""
   echo "$ROOTLV is already mounted on \"$ROOTMOUNTEDON\"."
fi
if [ "$BOOTMOUNTEDON$ROOTMOUNTEDON" ]; then
   echo ""
   read -p "Do you want to recover these filesystems anyhow? (y/n):" ans
   if [ "$ans" != "y" ]; then
      exit 1
   fi
fi

BOOT_UUID_NEW=`ls -l /dev/disk/by-uuid/|grep "$BOOTPART$"|awk '{print $9}'`
BOOT_UUID_OLD=`grep -w "/boot" $RECOVERYSOURCE/etc/fstab|awk '{print $1)'`
if [ "${BOOT_UUID_OLD/UUID=}" = "$BOOT_UUID_OLD" ]; then
   BOOT_UUID_OLD=""
else
   BOOT_UUID_OLD="${BOOT_UUID_OLD/UUID=}"
fi
echo "BOOT_UUID_OLD:$BOOT_UUID_OLD"
echo "BOOT_UUID_NEW:$BOOT_UUID_NEW"

mount|awk '{print $3}' | grep "^$RECOVERYDEST" | sort -r | xargs -l1 umount >/dev/null 2>&1

# mkdir -p $RECOVERYDEST
vgscan
vgchange -a y $ROOTVG


grep -v "^#" $RECOVERYSOURCE/etc/fstab | egrep -e "^/dev/mapper/$ROOTVG\-" -e "^/dev/$ROOTVG" | grep -wv "swap" | awk '{print $2}' | sort | while read fsdevice mp x
do
   echo "mount $fsdevice $RECOVERYDEST/$mp"
   # mkdir -p $RECOVERYDEST/$mp
   # mount $fsdevice $RECOVERYDEST/$mp
done

echo "mount /dev/$BOOTPART $RECOVERYDEST/boot"
# mount /dev/$BOOTPART $RECOVERYDEST/boot

echo "rsync -a --delete $RECOVERYSOURCE/ $RECOVERYDEST/"
# rsync -a --delete $RECOVERYSOURCE/ $RECOVERYDEST/

if [ "$BOOT_UUID_NEW" != "$BOOT_UUID_OLD" -a "$BOOT_UUID_OLD" != "" ]; then
   sed -i "s/$BOOT_UUID_OLD/$BOOT_UUID_NEW/g" $RECOVERYDEST/boot/grub2/grub.cfg
   sed -i "s/$BOOT_UUID_OLD/$BOOT_UUID_NEW/g" $RECOVERYDEST/etc/fstab
fi

echo "/sbin/grub2-install /dev/$BOOTDEVICE --boot-directory $RECOVERYDEST/boot"
# /sbin/grub2-install /dev/$BOOTDEVICE --boot-directory $RECOVERYDEST/boot

