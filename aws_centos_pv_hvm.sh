#!/bin/bash

echo -e "Display your volumes \n *******************" | tee -a /mnt/script.log
lsblk | tee -a /mnt/script.log

echo -e "Create a new partition on xvdg (xvdg1 will be created) \n *********************************************" | tee -a /mnt/script.log

parted /dev/xvdg --script 'mklabel msdos mkpart primary 1M -1s print quit' | tee -a /mnt/script.log
partprobe /dev/xvdg 
udevadm settle 

echo -e "Display your volumes \n *******************" | tee -a /mnt/script.log
lsblk | tee -a /mnt/script.log

echo -e "Check the source volume and minimize the size of original filesystem to speed up the process. We do not want to copy free disk space in the next step. \n *********************************************" | tee -a /mnt/script.log

e2fsck -fy /dev/xvdf | tee -a /mnt/script.log
resize2fs -M /dev/xvdf | tee -a /mnt/script.log

echo -e "Duplicate sourc to destination volume" '\n' "*********************************************"  | tee -a /mnt/script.log
dd if=/dev/xvdf of=/dev/xvdg1 bs=$(blockdev --getbsz /dev/xvdf) count=$(dumpe2fs /dev/xvdf | grep "Block count:" | cut -d : -f2 | tr -d "\\ ")
ret=$?
if [ $ret gt 0 ]; then
    echo -e "Duplicate source to destination volume failed ...."  | tee -a /mnt/script.log
else 
	echo -e "Duplicate source to destination volume succeed" | tee -a /mnt/script.log
fi

echo -e "Resize the 'destination' volume to maximum \n ***********************" | tee -a /mnt/script.log
e2fsck -f /dev/xvdg1 | tee -a /mnt/script.log
resize2fs /dev/xvdg1  | tee -a /mnt/script.log

echo -e "Prepare the destination volume \n *************************" | tee -a /mnt/script.log
mount /dev/xvdg1 /mnt/ && mount -o bind /dev/ /mnt/dev && mount -o bind /sys /mnt/sys && mount -o bind /proc /mnt/proc
ret1=$?
if [ $ret1 gt 0 ]; then
    echo -e "Prepare the destination volume failed...."  | tee -a /mnt/script.log
else 
	echo -e "Prepare the destination volume succeed" | tee -a /mnt/script.log
fi
echo "sucessfully completed few task......." | tee -a /mnt/script.log

