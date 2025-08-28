#!/usr/bin/env bash

sudo pacman -Sy fzf

set -e

# Colors
RESET="\033[0m"
INFO="\033[1;34m"    # Blue
ROOT="\033[1;31m"    # Red
OK="\033[1;32m"      # Green
WARN="\033[1;33m"    # Yellow
WM="\033[1;35m"      # Magenta for WM
DE="\033[1;36m"      # Cyan for DE

echo -e "${INFO}[INFO] Starting Arch installation script...${RESET}"

# --- Ask user input ---
echo -e "${INFO}Enter hostname:${RESET}"
read HOSTNAME
echo -e "${INFO}Enter username:${RESET}"
read USERNAME
echo -e "${INFO}Enter root password (will be visible):${RESET}"
read ROOT_PASS
echo -e "${INFO}Enter additional packages (comma-separated, e.g., firefox, kitty):${RESET}"
read EXTRA_PKGS
EXTRA_PKGS=$(echo "$EXTRA_PKGS" | sed 's/,/ /g')

# --- Partitioning ---
echo -e "${INFO}[INFO] Starting partitioning...${RESET}"
cfdisk

BOOT_PART=$(lsblk -lpno NAME | fzf --prompt="Select boot partition: ")
ROOT_PART=$(lsblk -lpno NAME | fzf --prompt="Select root partition: ")

echo -e "${WARN}Formatting boot partition...${RESET}"
mkfs.fat -F32 "$BOOT_PART"
echo -e "${WARN}Formatting root partition...${RESET}"
mkfs.ext4 "$ROOT_PART"

echo -e "${INFO}Mounting partitions...${RESET}"
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$BOOT_PART" /mnt/boot

# --- Display Manager choice ---
DM=$(printf "ly\nlxdm\ngdm\nlightdm\nsddm\n" | fzf --prompt="Select display manager: ")

# --- Base system ---
echo -e "${ROOT}[ROOT] Installing base system...${RESET}"
pacstrap -K /mnt base base-devel linux-firmware pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse networkmanager efibootmgr fzf git sudo "$DM"

# --- Generate fstab ---
echo -e "${INFO}[INFO] Generating fstab...${RESET}"
genfstab -U /mnt >> /mnt/etc/fstab

# --- Chroot and configure system ---
arch-chroot /mnt /bin/bash <<EOF
echo -e "${INFO}[INFO] Inside chroot... Starting configuration${RESET}"

echo -e "${WARN}Setting hostname...${RESET}"
echo "$HOSTNAME" > /etc/hostname

echo -e "${WARN}Configuring locale...${RESET}"
sed -i 's/#en_GB.UTF-8/en_GB.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf
echo "KEYMAP=de" > /etc/vconsole.conf

echo -e "${WARN}Setting root password...${RESET}"
echo "root:$ROOT_PASS" | chpasswd

echo -e "${WARN}Creating user: $USERNAME...${RESET}"
useradd -m -G wheel "$USERNAME"
passwd -d "$USERNAME"

echo -e "${WARN}Granting sudo privileges to wheel group...${RESET}"
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

echo -e "${WARN}Enabling essential services...${RESET}"
systemctl enable NetworkManager
systemctl enable "$DM"

echo -e "${OK}[OK] Basic chroot configuration complete.${RESET}"
EOF

# --- Install yay as the user ---
arch-chroot /mnt /bin/bash <<EOF
su - "$USERNAME" -c "cd ~ && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm"
EOF

# --- Kernel via yay ---
arch-chroot /mnt /bin/bash <<EOF
su - "$USERNAME" -c "yay --noconfirm -S linux-bazzite-bin"
EOF

# --- Install additional packages if provided ---
if [ -n "$EXTRA_PKGS" ]; then
    echo -e "${INFO}[INFO] Installing additional packages: $EXTRA_PKGS${RESET}"
    arch-chroot /mnt /bin/bash <<EOF
su - "$USERNAME" -c "yay --noconfirm -S $EXTRA_PKGS"
EOF
fi

# --- Wayland-focused DE/WM list ---
DEWM_LIST="
${DE}GNOME${RESET}
${DE}COSMIC${RESET}
${DE}Pantheon${RESET}
${DE}Budgie${RESET}
${DE}Cinnamon${RESET}
${DE}MATE${RESET}
${DE}Deepin${RESET}
${WM}Hyprland${RESET}
${WM}Sway${RESET}
${WM}River${RESET}
${WM}Wayfire${RESET}
${WM}Labwc${RESET}
${WM}Niri${RESET}
${WM}Hikari${RESET}
${WM}Velox${RESET}
${WM}Dwl${RESET}
"

echo -e "${INFO}[INFO] Select DE/WM to install...${RESET}"
SELECTED=$(echo -e "$DEWM_LIST" | sed 's/\x1B\[[0-9;]*[JKmsu]//g' | fzf --multi)

if [ -n "$SELECTED" ]; then
    arch-chroot /mnt /bin/bash <<EOF
    yay --noconfirm -S $SELECTED
EOF
fi

echo -e "${OK}[OK] Installation complete. You can now reboot.${RESET}"
