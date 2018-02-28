#!/bin/bash
#
# Create an rsync backup / snapshot of root volume filesystems
#
# T.McGinnis 2/2018
#
# version 0.1
#
RECOVERYSOURCE=/mnt/bootrecovery/root
RECOVERYDEVICE="sda"
BOOTPART=$BOOTDEVICE"1"

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

grep -v "^#" /etc/fstab | egrep -e "^/dev/mapper/$ROOTVG\-" -e "^/dev/$ROOTVG" | grep -wv "swap" | awk '{print $2}' | sort | while read mp
do
   echo "rsync -a --one-file-system --delete $mp/ $RECOVERYSOURCE$mp/"
done

echo "rsync -a --one-file-system --delete /boot $RECOVERYSOURCE/boot/"
