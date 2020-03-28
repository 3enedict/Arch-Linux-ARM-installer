#!/bin/bash

# Make sure that you have configured this file to your heart's desire. 
# It is recommended to install arch manually at least once (so that you know what you're doing).
# Oh and remember, scripts are DUMB !!

if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root."
  exit
fi

lsblk
echo Could you please point me out where to install arch ? Always press 0 for options.
read install_pnt

if [ $install_pnt -eq '0' ]; then
  echo These are the preinstalled options : 
  echo   - 1 : sdb
  echo   - 2 : sdc
  echo   - 3 : mmcblk0
  echo
  read install_pnt
fi

if [ $install_pnt -eq '1' ]; then
  install_pnt='sdb'
elif [ $install_pnt -eq '2' ]; then
  install_pnt='sdc'
elif [ $install_pnt -eq '3' ]; then
  install_pnt='mmcblk0'
fi

echo Are you sure you want to install arch linux on $install_pnt ?
read agree

if [ $agree -eq '0' ]; then
  echo These are the preinstalled options : 
  echo   - n or no : stop program
  echo   - anything else : continue program
  echo
  read agree
fi

if [ "$agree" == "n" ] || [ "$agree" == "no"]; then
  echo Ok, exitting.
  exit 1
else
  sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/${install_pnt}
  o
  n



  +100M
  t
  c
  n




  w
EOF
fi

lsblk
echo Could you please point me out the first partition ?
read partition1

if [ $partition1 -eq '0' ]; then
  echo These are the preinstalled options : 
  echo   - 1 : sdb1
  echo   - 2 : sdc1
  echo   - 3 : mmcblk0p1
  echo   - 4 : sdb1 and sdb2
  echo   - 5 : sdc1 and sdc2
  echo   - 6 : mmcblk0p1 and mmcblk0p2
  echo
  read partition1
fi

if [ $partition1 -eq '1' ]; then
  partition1='sdb1'
  echo Could you now point me out the second partition ?
  read partition2
elif [ $partition1 -eq '2' ]; then
  partition1='sdc1'
  echo Could you now point me out the second partition ?
  read partition2
elif [ $partition1 -eq '3' ]; then
  partition1='mmcblk0p1'
  echo Could you now point me out the second partition ?
  read partition2
elif [ $partition1 -eq '4' ]; then
  partition1='sdb1'
  partition2='sdb2'
elif [ $partition1 -eq '5' ]; then
  partition1='sdc1'
  partition2='sdc2'
elif [ $partition1 -eq '6' ]; then
  partition1='mmcblk0p1'
  partition2='mmcblk0p2'
fi

mkfs.vfat /dev/${partition1}
mkdir boot/
mount /dev/${partition1} boot/

mkfs.ext4 /dev/${partition2}
mkdir root/
mount /dev/${partition2} root/

echo Do you want to install arch version 2 or 3 ?
read version

if [ $version -eq '0' ]; then
  echo These are the preinstalled options :
  echo   - 2 : installs Arch Linux ARM rpi 2 with usb boot.
  echo   - 3 : installs Arch Linux ARM rpi 3.
  echo
  read version
fi

if [ ! -f "ArchLinuxARM-rpi-${version}-latest.tar.gz" ]; then
  wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-${version}-latest.tar.gz
fi 

bsdtar -xpf ArchLinuxARM-rpi-${version}-latest.tar.gz -C root
sync
mv root/boot/* boot

if [ $version -eq '2' ]; then
  sed -i 's/mmcblk0p2/sda2/g' boot/cmdline.txt
  sed -i 's/mmcblk0p1/sda1/g' root/etc/fstab
  echo program_usb_boot_mode=1 >> boot/config.txt 
fi

umount boot root
rm -r boot/
rm -r root/

echo 
echo There we go, arch should now be installed on $install_pnt !
