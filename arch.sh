#!/bin/bash

# Make sure that you have configured this file to your heart's desire. 
# It is recommended to install arch manually at least once (so that you know what you're doing).
# Oh and remember, scripts are DUMB !!

if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root."
  exit
fi

ui_check () {
  firstitem=$1
  options=""
  shift;
  for item in "$@" ; do
    options="$options/$item"
  done
  printf "%s (%s) : " "$firstitem" "${options:1}"
  read var

  go=0
  while [ $go -eq 0 ]; do
    for item in "$@" ; do
      if [ "$item" == "$var" ]; then
        go=1
      fi
    done
    if [ $go -eq 0 ]; then
      printf "I am sorry but the value that you just gave me is not valid. Check the options up top : "
      read var
    fi
  done

  ret=$var
}

ui_check_disk () {
  lsblk
  firstitem=$1
  shift;

  proceed=0
  while [ $proceed -eq 0 ]; do
    printf "\n$firstitem : "
    read storage

    for item in "$@" ; do
      IFS=':'
      array=( $item )
      if [ "$storage" == "${array[0]}" ]; then
        storage="${array[1]}"
      fi
    done


    if [ -b /dev/$storage ]; then
      ui_check "Are you sure you want to use '/dev/$storage'" "y" "n"
      use=$ret
      if [ "$use" == "y" ]; then
        proceed=1
      else
        printf "Ok. "
      fi
    else 
      printf "It seems that '/dev/$storage' does not exist. "
    fi
  done

  ret=$storage
}

confirm () {
  proceed=0
  while [ $proceed -eq 0 ]; do
    printf "Could you please give me $1 : "
    read conf1

    ui_check "Is '$conf1' correct" "y" "n"
    if [ "$ret" == "y" ]; then
      proceed=1
    else 
      printf "Ok. "
    fi
  done

  ret=$conf1
}


ui_check "First off, which version of arch linux do you want to install" 2 3
version=$ret

ui_check "Do you want to enable usb boot" "y" "n"
usb=$ret
if [ "$usb" == "y" ] && [ $version -eq 3 ]; then
  printf "In that case, you are going to have to use arch linux version 2\n" 
  version=2
fi

ui_check "Do you want to enable the pi's camera" "y" "n"
cam=$ret

ui_check "Do you want to enable wifi" "y" "n"
wifi=$ret 
if [ "$wifi" == "y" ]; then
  confirm "your router's SSID"
  SSID=$ret
  confirm "your router's password"
  pass=$ret
fi

printf "What do you want the main user's name to be (default is alarm) : "
read name
if [ "$name" == "" ]; then
  name="alarm"
fi

confirm "$name's password"
pass_main=$ret

confirm "root's password"
pass_root=$ret

read -p "Ok, you can now plug in your storage device (press enter to continue)"

ui_check_disk "Could you give me the disk you want to install arch on (sd = mmcblk0)" "sd:mmcblk0"
disk=$ret
if [ "$use" == "y" ]; then
  sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/${disk}
o
n



+100M
t
c
n




w
EOF
fi

ui_check_disk "Could you point me to the first partition of $disk (sd = mmcblk0p1)" "sd:mmcblk0p1"
part1=$ret

ui_check_disk "Could you point me to the second partition of $disk (sd = mmcblk0p2)" "sd:mmcblk0p2"
part2=$ret

if [ ! -f "ArchLinuxARM-rpi-${version}-latest.tar.gz" ]; then
  wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-${version}-latest.tar.gz
fi

if [ ! -d "arch$version" ]; then
  mkdir arch$version
  bsdtar -xpf ArchLinuxARM-rpi-${version}-latest.tar.gz -C arch$version
fi 

if [ -d "root" ]; then
  rm -r root/*
else 
  mkdir root
fi

if [ -d "boot" ]; then
  rm -r boot/*
else 
  mkdir boot  
fi

mkfs.vfat /dev/${part1}
mkfs.ext4 /dev/${part2}
mount /dev/${part1} boot/
mount /dev/${part2} root/

cp -r arch$version/* root/
sync
mv root/boot/* boot/

if [ "$usb" == "y" ]; then
  sed -i 's/mmcblk0p2/sda2/g' boot/cmdline.txt
  sed -i 's/mmcblk0p1/sda1/g' root/etc/fstab
  echo program_usb_boot_mode=1 >> boot/config.txt 
fi

if [ "$cam" == "y" ]; then
  echo "gpu_mem=128 start_file=start_x.elf fixup_file=fixup_x.dat" >> boot/config.txt
  echo "cma_lwm= cma_hwm= cma_offline_start=" >> boot/config.txt
  echo "blacklist i2c_bcm2708" >> /etc/modprobe.d/blacklist.conf
  echo "bcm2835-v4l2" >> /etc/modules-load.d/rpi-camera.conf
fi

sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' root/etc/ssh/sshd_config
sed -i 's/#LLMNR=yes/LLMNR=no/g' root/etc/systemd/resolved.conf

touch root/home/alarm/.script.sh

cat <<EOT >> root/home/alarm/.script.sh
pacman-key --init
pacman-key --populate archlinuxarm
echo "root:$pass_root" | chpasswd
echo "alarm:$pass_main" | chpasswd
usermod -l $name alarm
EOT

if [ $wifi == "y" ]; then
  cat <<EOT >> root/home/alarm/.script.sh
cd /etc/netctl/
install -m640 examples/wireless-wpa wifi
sed -i "s/ESSID='MyNetwork'/ESSID='$SSID'/g" wifi
sed -i "s/Key='WirelessKey'/Key='$pass'/g" wifi
netctl start wifi
netctl enable wifi
cd ~/
EOT
fi

umount root/ boot/ 
rm -r root/ boot/

printf "There we go, arch should now be installed on $disk !\n"
read -p "You can now plug your storage media in your raspberry pi. Press enter to continue."

confirm "your pi's ip address"
ip=$ret

ssh-keygen -f "/root/.ssh/known_hosts" -R "$ip"

ssh root@${ip} <<'ENDSSH'
cd /home/alarm/
chmod +x .script.sh
./.script.sh
exit
ENDSSH

printf "Ok, your raspberry pi should now be rebooting. You might want to check out any errors\n"
