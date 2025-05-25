#!/usr/bin/env bash

# Color codes
CYAN="\033[1;36m"
RED="\033[0;31m"
LIGHTRED="\033[1;31m"
GREEN="\033[0;32m"
BROWN="\033[0;33m"
YELLOW="\033[1;33m"
PURPLE="\033[0;35m"
LIGHTPURPLE="\033[1;35m"
RESET="\033[0m"

# Check for UEFI mode
if [[ -f /sys/firmware/efi/fw_platform_size ]]; then
    echo "${LIGHTRED}System not booted in UEFI mode! Aborting.${RESET}"
    #exit 1
fi
# Prepare environment
loadkeys de-latin1
timedatectl set-timezone Europe/Berlin

# Prompt the user to choose a target disk for the Arch installation
echo -e "${LIGHTPURPLE}Choose the disk you want to install Arch on:${RESET}"
lsblk -o PATH,SIZE,VENDOR,MODEL,SERIAL --filter 'TYPE=="disk"' | awk -v header="$PURPLE" -v reset="$RESET" 'NR==1 {print header $0 reset; next} {print}'
echo -en "${CYAN}Target disk (e.g., /dev/sdX):${RESET} "
read -r target_disk
if [[ ! -b "$target_disk" ]]; then
  echo -e "${LIGHTRED}ERROR: '$target_disk' is not a valid block device.${RESET}"
  exit 1
fi

#
# START THE INSTALLATION!
#

# Unmount all partitions of the target disk
findmnt --filter "SOURCE=~'${target_disk}'" -o TARGET -rn | tac | while read -r mp; do
  echo "Unmounting $mp..."
  umount "$mp" || echo "Failed to unmount $mp"
done

# RECOMMENDED PARITION LAYOUT
# - Taken from openSUSE Tumbleweed 20250503 with BTRFS
#
#
#
# sfdisklabel: gpt
# label-id: AB9086CB-73F4-4BFE-B5EB-2A5376E54868
# device: /dev/sda
# unit: sectors
# first-lba: 34
# last-lba: 266338270
# sector-size: 512
# 
# /dev/sda1 : start=        2048, size=     2097152, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, uuid=EDFB49C4-0FD8-46AF-8AA1-44BE632F4751
# $linux_part : start=     2099200, size=   260042752, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=EEEF71D7-CE54-4A5C-B854-D2251BFC5372
# /dev/sda3 : start=   262141952, size=     4196319, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F, uuid=67DF81F0-F8CB-42AE-A173-7D93364BC75C
#
#
# REALISATION USING GDISK
# - Assuming a 1TB disk
#
# gdisk /dev/<disk>
# o
# n,default,default,+1G,ef00
# n,default,default,+928G,default
# n,default,default,default,8200
# w
echo
echo -e "${LIGHTPURPLE}Please partition your disk ($target_disk)${RESET}"
echo "  Here is a sample layout:"
echo "    # gdisk $target_disk"
echo "    # o"
echo "    # n,default,default,+4G,ef00"
echo "    # n,default,default,+920G,default"
echo "    # n,default,default,default,8200"
echo "    # w"
bash --init-file <(echo "echo -e '${YELLOW}';gdisk ${target_disk};echo -e '${RESET}';exit")

echo -en "${CYAN}Which partition is your EFI:${RESET} "
read -r efi_part
echo -en "${CYAN}Which partition is your Linux filesystem:${RESET} "
read -r linux_part
echo -en "${CYAN}Which partition is your swap filesystem:${RESET} "
read -r swap_part

mkfs.fat -F 32 $efi_part
mkfs.btrfs $linux_part
mkswap $swap_part

mount $linux_part /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@pacman_pkg
#btrfs subvolume create /mnt/btrfs/@/.snapshots
btrfs subvolume set-default /mnt/@

umount /mnt
mount --mkdir -o subvol=/@ $linux_part /mnt
mount --mkdir -o subvol=/@root $linux_part /mnt/root
mount --mkdir -o subvol=/@home $linux_part /mnt/home
mount --mkdir -o subvol=/@var_log $linux_part /mnt/var/log
mount --mkdir -o subvol=/@pacman_pkg $linux_part /mnt/var/cache/pacman/pkg
mount --mkdir -o fmask=0177,dmask=0077,noexec,nosuid,nodev $efi_part /mnt/boot
swapon $swap_part

# Install essential packages
reflector --country DE > /etc/pacman.d/mirrorlist
pacstrap -K /mnt base linux linux-firmware intel-ucode btrfs-progs dosfstools neovim ansible vim-ansible

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

# chroot
arch-chroot /mnt <<EOF
# Time and date
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc

#Localisation
sed -i 's/^#[[:space:]]*\(en_US\.UTF-8[[:space:]]*UTF-8\)[[:space:]]*$/\1/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=de-latin1" > /etc/vconsole.conf
echo "FONT=eurlatgr" >> /etc/vconsole.conf
echo "spectre" > /etc/hostname

bootctl --esp-path=/boot install


cat << EOF2 >> /boot/loader/loader.conf
default      arch.conf
timeout      4
console-mode max
editor       no
EOF2

cat << EOF2 >> /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=$(lsblk -o uuid -n $linux_part)
EOF2

EOF


#ansible-playbook -i localhost, playbook.yml