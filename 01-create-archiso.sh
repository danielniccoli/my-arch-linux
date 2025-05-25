#!/usr/bin/env bash

if [ ! -v ARCHISO_BASEDIR ]; then
  ARCHISO_BASEDIR="${HOME%/}/archiso"
fi
if [ ! -v ARCHISO_LIVEDIR ]; then
  ARCHISO_LIVEDIR="${ARCHISO_BASEDIR%/}/archlive"
fi
if [ ! -v ARCHISO_WORKDIR ]; then
  ARCHISO_WORKDIR="/tmp/archiso-tmp"
fi
if [ ! -v ARCHISO_OUTDIR ]; then
  ARCHISO_OUTDIR="${ARCHISO_BASEDIR%/}/archout"
fi

pacman -Sy
pacman -S --noconfirm archiso

[ -d "${ARCHISO_BASEDIR%/}" ] && rm -r "${ARCHISO_BASEDIR%/}"
mkdir -p "$ARCHISO_BASEDIR"
[ -d "${ARCHISO_WORKDIR%/}" ] && rm -r "${ARCHISO_WORKDIR%/}"
mkdir -p "$ARCHISO_WORKDIR"

####
#### https://wiki.archlinux.org/title/Archiso
####

# Prepare custom profile:
cp -r /usr/share/archiso/configs/releng/ "${ARCHISO_LIVEDIR%/}"

echo "KEYMAP=de-latin1" > "${ARCHISO_LIVEDIR%/}/airootfs/etc/vconsole.conf"
cp /usr/share/zoneinfo/Europe/Berlin "${ARCHISO_LIVEDIR%/}/airootfs/etc/localtime"

# Set locale
cat << EOF > "${ARCHISO_LIVEDIR%/}/airootfs/etc/locale.gen"
en_US.UTF-8 UTF-8
de_DE.UTF-8 UTF-8
EOF
cat << EOF > "${ARCHISO_LIVEDIR%/}/airootfs/etc/pacman.d/hooks/locale-gen.hook"
# remove from airootfs!
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = glibc

[Action]
Description = Generating localisation files...
When = PostTransaction
Depends = glibc
Exec = /usr/bin/locale-gen
EOF

# Add packages
cat << EOF >> "${ARCHISO_LIVEDIR%/}/packages.x86_64"
ansible
neovim
vim-ansible
EOF

# Build the ISO
mkarchiso -v -w "${ARCHISO_WORKDIR%/}" -o "${ARCHISO_OUTDIR%/}" "${ARCHISO_LIVEDIR%/}"
cp "${ARCHISO_OUTDIR%/}/archlinux-$(date +%Y.%m.%d)-x86_64.iso" /mnt/c/temp/custom-archiso.iso