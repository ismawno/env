#!/bin/bash

dest="$HOME/env/env/"

mkdir -p $dest/etc/default
mkdir -p $dest/etc/modprobe.d

sudo cp /etc/mkinitcpio.conf $dest/etc
sudo cp /etc/default/grub $dest/etc/default
sudo cp /etc/locale.gen $dest/etc
sudo cp /etc/locale.conf $dest/etc
sudo cp /etc/vconsole.conf $dest/etc
sudo cp /etc/modprobe.d/nvidia.conf $dest/etc/modprobe.d

cd $dest
pacman -Qe > packages.txt
yay -Qm > aurs.txt

systemctl list-units --type=service --state=enabled > enabled-services.txt

