#!/usr/bin/env bash

# install needed packages
sudo pacman -S fzf

set -e

# --- Colors ---
RESET="\033[0m"
INFO="\033[1;34m"
ROOT="\033[1;31m"
OK="\033[1;32m"
WARN="\033[1;33m"

echo -e "${INFO}[INFO] Starting Arch installation script...${RESET}"

# --- User input ---
echo -e "${INFO}Enter hostname:${RESET}"
read HOSTNAME
echo -e "${INFO}Enter username:${RESET}"
read USERNAME
echo -e "${INFO}Enter root password (visible):${RESET}"
read ROOT_PASS

# --- Partitioning ---
echo -e "${INFO}[INFO] Launching cfdisk for partitioning...${RESET}"
cfdisk

BOOT_PART=$(lsblk -lpno NAME | fzf --prompt="Select boot partition: ")
ROOT_PART=$(lsblk -lpno NAME | fzf --prompt="Select root partition: ")

echo -e "${WARN}[ACTION] Formatting partitions...${RESET}"
mkfs.fat -F32 "$BOOT_PART"
mkfs.ext4 "$ROOT_PART"

echo -e "${INFO}[ACTION] Mounting partitions...${RESET}"
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$BOOT_PART" /mnt/boot

# --- Install yay in live ISO ---
echo -e "${INFO}[INFO] Installing yay in live environment...${RESET}"
cd ~
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ~

# --- Display Manager ---
DM=$(printf "ly\nlxdm\ngdm\nlightdm\nsddm\n" | fzf --prompt="Select display manager: ")

# --- Base system (no kernel) ---
echo -e "${ROOT}[ROOT] Pacstrapping base system...${RESET}"
pacstrap -K /mnt base base-devel sudo linux-firmware networkmanager efibootmgr fzf git "$DM"

# --- Kernel via yay ---
echo -e "${INFO}[INFO] Installing kernel via yay into /mnt...${RESET}"
yay --root /mnt --noconfirm -S linux-bazzite-bin

# --- Generate fstab ---
echo -e "${INFO}[INFO] Generating fstab...${RESET}"
genfstab -U /mnt >> /mnt/etc/fstab

# --- Chroot configuration ---
arch-chroot /mnt /bin/bash <<EOF
RESET="\033[0m"
INFO="\033[1;34m"
ROOT="\033[1;31m"
OK="\033[1;32m"
WARN="\033[1;33m"

echo -e "\${INFO}[CHROOT] Configuring system...\${RESET}"

# Hostname and locale
echo -e "\${WARN}Setting hostname...\${RESET}"
echo "$HOSTNAME" > /etc/hostname
sed -i 's/#en_GB.UTF-8/en_GB.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf
echo "KEYMAP=de" > /etc/vconsole.conf

# Root password
echo -e "\${WARN}Setting root password...\${RESET}"
echo "root:$ROOT_PASS" | chpasswd

# User creation
echo -e "\${WARN}Creating user $USERNAME...\${RESET}"
useradd -m -G wheel "$USERNAME"
passwd -d "$USERNAME"
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Enable essential services
echo -e "\${WARN}Enabling NetworkManager and $DM...\${RESET}"
systemctl enable NetworkManager
systemctl enable "$DM"

# Install yay for user
echo -e "\${INFO}[CHROOT] Installing yay for user...\${RESET}"
su - "$USERNAME" -c "cd ~ && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm"

# DE/WM selection
echo -e "\${INFO}[CHROOT] Selecting DE/WM to install...\${RESET}"
DEWM=\$(yay -Ss | awk '{print \$1}' | grep -E 'desktop|wm' | fzf --multi)

if [ -n "\$DEWM" ]; then
    for pkg in \$DEWM; do
        if pacman -Si \$pkg &>/dev/null; then
            echo -e "\${INFO}[CHROOT] Installing \$pkg via pacman...\${RESET}"
            pacman --noconfirm -S \$pkg
        else
            echo -e "\${INFO}[CHROOT] Installing \$pkg via yay...\${RESET}"
            su - "$USERNAME" -c "yay --noconfirm -S \$pkg"
        fi
    done
fi

echo -e "\${OK}[CHROOT] Configuration complete. Exiting chroot.\${RESET}"
EOF

echo -e "${OK}[OK] Installation finished. Back in Arch ISO environment. You can reboot.${RESET}"
