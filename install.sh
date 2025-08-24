#!/usr/bin/env bash

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

# --- Display Manager ---
DM=$(printf "ly\nlxdm\ngdm\nlightdm\nsddm\n" | fzf --prompt="Select display manager: ")

# --- Base system (no kernel) ---
echo -e "${ROOT}[ROOT] Installing base system and essential packages...${RESET}"
pacstrap -K /mnt base base-devel sudo linux-firmware networkmanager efibootmgr fzf git nano micro alacritty "$DM"

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
echo -e "\${INFO}[CHROOT] Installing yay for user $USERNAME...\${RESET}"
su - "$USERNAME" -c "cd ~ && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm"

# Install linux-bazzite-bin kernel via yay
echo -e "\${INFO}[CHROOT] Installing linux-bazzite-bin kernel...\${RESET}"
su - "$USERNAME" -c "yay --noconfirm -S linux-bazzite-bin"

# --- DE/WM selection ---
# Blue for DE, Orange for WM
DEWM_LIST="
\033[1;34mXfce\033[0m
\033[1;34mLXQt\033[0m
\033[1;34mHyprland\033[0m
\033[1;34mGNOME\033[0m
\033[1;34mKDE\033[0m
\033[1;34mBudgie\033[0m
\033[1;34mCinnamon\033[0m
\033[1;34mMATE\033[0m
\033[1;34mPantheon\033[0m
\033[1;33mi3\033[0m
\033[1;33mSway\033[0m
\033[1;33mAwesome\033[0m
\033[1;33mOpenbox\033[0m
\033[1;33mLumina\033[0m
\033[1;33mBspwm\033[0m
\033[1;33mFluxbox\033[0m
\033[1;33mIceWM\033[0m
\033[1;33mDeepin\033[0m
\033[1;33mEnlightenment\033[0m
\033[1;33mPekWM\033[0m
\033[1;33mJWM\033[0m
\033[1;33mHerbstluftwm\033[0m
\033[1;33mQtile\033[0m
\033[1;33mDWM\033[0m
\033[1;33mBlackbox\033[0m
\033[1;33mNotion\033[0m
\033[1;33mRegolith\033[0m
\033[1;33mAfterStep\033[0m
\033[1;33mFVWM\033[0m
\033[1;33mTrinity\033[0m
\033[1;33mSawfish\033[0m
\033[1;33mMutter\033[0m
\033[1;33mCompiz\033[0m
\033[1;33mRatpoison\033[0m
"

echo -e "\${INFO}[CHROOT] Select a DE/WM to install...${RESET}"
SELECTED_DEWM=\$(echo -e "\$DEWM_LIST" | fzf --ansi --multi --prompt="Select DE/WM(s): ")

# Strip color codes for installation
for pkg in \$SELECTED_DEWM; do
    pkg_trim=\$(echo -e "\$pkg" | sed 's/\\x1b\\[[0-9;]*m//g' | xargs)
    if [ -z "\$pkg_trim" ]; then
        continue
    fi
    if pacman -Si \$pkg_trim &>/dev/null; then
        echo -e "\${INFO}[CHROOT] Installing \$pkg_trim via pacman...\${RESET}"
        pacman --noconfirm -S \$pkg_trim
    else
        echo -e "\${INFO}[CHROOT] Installing \$pkg_trim via yay...\${RESET}"
        su - "$USERNAME" -c "yay --noconfirm -S \$pkg_trim"
    fi
done

echo -e "\${OK}[CHROOT] Configuration complete. Exiting chroot.\${RESET}"
EOF

echo -e "${OK}[OK] Installation finished. Back in Arch ISO environment. You can now reboot.${RESET}"
