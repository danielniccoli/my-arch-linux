#!/bin/bash

# Color codes
HEADER="\033[1;36m"  # Bright cyan
RESET="\033[0m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
GREEN="\033[0;32m"

echo -e "${HEADER}Available block devices:${RESET}"
echo

# Print lsblk output, using header color variable
lsblk -o VENDOR,MODEL,SERIAL,PATH,SIZE --filter 'TYPE=="disk"' | awk -v header="$HEADER" -v reset="$RESET" 'NR==1 {print header $0 reset; next} {print}'

echo
read -rp "$(echo -e ${YELLOW}Enter the *path* of the disk you want to use for Arch installation (e.g., /dev/sdX):${RESET} )" disk_path

if [[ ! -b "$disk_path" ]]; then
  echo -e "${RED}Error:${RESET} '$disk_path' is not a valid block device."
  exit 1
fi

echo
echo -e "${RED}WARNING:${RESET} All data on $disk_path will be permanently lost."
read -rp "$(echo -e ${YELLOW}Are you absolutely sure you want to format this drive? Type 'YES' to confirm:${RESET} )" confirm

if [[ "$confirm" != "YES" ]]; then
  echo -e "${GREEN}Aborted. No changes made.${RESET}"
  exit 0
fi

echo -e "${GREEN}Confirmed. You can now proceed with formatting $disk_path.${RESET}"
# Add formatting logic here if desired

