#!/usr/bin/env bash

# Use --needed to only install if missing, keeping it clean
sudo pacman -Sy --needed --noconfirm fzf
sleep 2

set -euo pipefail

# Colors
RESET="\033[0m"
INFO="\033[1;34m"
ROOT="\033[1;31m"
OK="\033[1;32m"
WARN="\033[1;33m"

cat <<'EOF'
 _______________________________________
< SERVER MODE: NAKED ARCH + CASAOS BRO! >
 ---------------------------------------
\                             .       .
 \                           / \`.   .' " 
  \                  .---.  <    > <    >  .---.
   \                 |    \  \ - ~ ~ - /  /    |
         _____          ..-~             ~-..-~
        |     |   \~~~\.'                    \./~~~/
       ---------   \__/                        \__/
      .'  O    \     /               /       \  " 
     (_____,    \`._.'               |         }  \/~~~/
      \`----.          /       }     |        /    \__/
            \`-.      |       /      |       /      \`. ,~~|
                ~-.__|      /_ - ~ ^|      /- _      \`..-'   
                     |     /        |     /     ~-.     \`-. _  _  _
                     |_____|        |_____|         ~ - . _ _ _ _ _>
EOF
sleep 4

# --- User input ---
read -rp "$(echo -e "${INFO}Enter hostname:${RESET} ")" HOSTNAME
read -rp "$(echo -e "${INFO}Enter username (Worker for Docker/Web):${RESET} ")" USERNAME
read -rp "$(echo -e "${INFO}Root password:${RESET} ")" ROOT_PASS
read -rp "$(echo -e "${INFO}User password:${RESET} ")" USER_PASS
sleep 1

# --- Partitioning ---
echo -e "${INFO}[INFO] Waking up the partition manager...${RESET}"
sleep 3
cfdisk

BOOT_PART=$(lsblk -lpno NAME | fzf --prompt="Select pre-existing EFI partition: ")
ROOT_PART=$(lsblk -lpno NAME | fzf --prompt="Select server ROOT partition: ")

echo -e "${WARN}[WARN] Formatting $ROOT_PART as ext4...${RESET}"
sleep 4
mkfs.ext4 -F "$ROOT_PART"

echo -e "${INFO}[INFO] Mounting partitions for surgery...${RESET}"
sleep 2
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$BOOT_PART" /mnt/boot

# --- Base system ---
echo -e "${ROOT}[ROOT] Pacstrapping Naked Base + LQX Kernel...${RESET}"
echo -e "${INFO}(This is the heavy lifting, hold tight...)${RESET}"
sleep 5
BASE_PKGS="base base-devel linux-lqx linux-lqx-headers linux-firmware networkmanager git sudo docker cockpit cockpit-storaged grub"

pacstrap -K /mnt $BASE_PKGS

echo -e "${OK}[OK] Base system files are on the disk.${RESET}"
sleep 3

# --- Generate fstab ---
echo -e "${INFO}[INFO] Writing the fstab UUIDs...${RESET}"
genfstab -U /mnt >> /mnt/etc/fstab
sleep 2

# --- Chroot configuration ---
echo -e "${INFO}[INFO] Entering Chroot to wake up the OS...${RESET}"
sleep 4
arch-chroot /mnt bash <<EOF
set -euo pipefail

# Localization
echo "$HOSTNAME" > /etc/hostname
echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf

# Users
echo "root:$ROOT_PASS" | chpasswd
useradd -m -G wheel "$USERNAME"
echo "$USERNAME:$USER_PASS" | chpasswd
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Services
systemctl enable NetworkManager
systemctl enable docker
systemctl enable cockpit.socket

# Bootloader Ghost Config
grub-mkconfig -o /boot/grub/grub.cfg

# Install CasaOS (The Mobile Dashboard)
echo "Pulling the CasaOS dashboard module..."
curl -fsSL https://get.casaos.io | bash
EOF

# Grab IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo -e "${OK}=================================================${RESET}"
echo -e "${OK}[OK] INSTALLATION FINISHED SUCCESSFULLY!${RESET}"
echo -e "${OK}=================================================${RESET}"
echo -e "${WARN}CRITICAL STEPS TO FINISH (ON YOUR DAILY DRIVER):${RESET}"
echo -e "1. Reboot into your ${INFO}DAILY DRIVER${RESET}"
echo -e "2. Mount server root: ${INFO}sudo mount $ROOT_PART /mnt${RESET}"
echo -e "3. Update main GRUB: ${INFO}sudo grub-mkconfig -o /boot/grub/grub.cfg${RESET}"
echo -e "4. Reboot and select '${HOSTNAME}' from the list."
echo -e ""
echo -e "${WARN}PHONE CONTROL (ONCE BOOTED):${RESET}"
echo -e "CasaOS Dashboard: ${INFO}http://${SERVER_IP}${RESET}"
echo -e "System Vitals:   ${INFO}http://${SERVER_IP}:9090${RESET}"
echo -e ""
echo -e "${INFO}PRO-TIP:${RESET} Open in Vanadium and 'Add to Home Screen' for the app experience."
echo -e "${OK}=================================================${RESET}"
