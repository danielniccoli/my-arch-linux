#!/usr/bin/env bash

# Prepare environment
loadkeys de-latin1
setfont ter-v16b
timedatectl set-timezone Europe/Berlin


# REALISATION USING GDISK
# - Assuming a 1TB disk
#
# gdisk /dev/<disk>
# o
# n,default,default,+1G,ef00
# n,default,default,+928G,default
# n,default,default,default,8200
# w

lsblk
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

ln -sf /usr/lib/systemd/network/89-ethernet.network.example /etc/systemd/network/89-ethernet.network

EOF

pacstrap -K /mnt base linux linux-firmware intel-ucode btrfs-progs dosfstools neovim ansible vim-ansible

echo "YOU MUST arch-chroot INTO /mnt AND SET A ROOT PASSWORD!"

#ANSIBLE_PYTHON_INTERPRETER=auto_silent ansible-playbook -i localhost, playbook.yml