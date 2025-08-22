#!/usr/bin/env bash
set -euo pipefail

# Load config and WM functions
source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/wm.sh"

# ====== Utils ======
ask() { read -rp "$1: " "$2"; }
ask_hidden() { read -rsp "$1: " "$2"; echo; }

# ====== User Input ======
ask "Enter hostname" HOSTNAME
ask "Enter username" USERNAME
ask_hidden "Enter password for $USERNAME" USERPASS
ask_hidden "Enter root/sudo password" ROOTPASS

# Display manager selection
DM=$(fzf --height 10 --reverse --prompt "Select Display Manager: " \
    --bind "tab:toggle" <<< $'gdm\nsddm\nlightdm\nly\nnone')

# Terminal selection
TERM=$(fzf --height 5 --reverse --prompt "Select Terminal: " \
    --bind "tab:toggle" <<< $'ghostty\nkitty\nalacritty')

# WM/DE selection
WM=$(fzf --height 25 --reverse --prompt "Select DE/WM: " \
    --bind "tab:toggle" <<< $'Minimal\nServer\nHyprland\nKDE Plasma\nGNOME\nBudgie\nBSPWM\ni3\ni3-gaps\nXmonad\nRiver\nSway\nCosmic\nLumina\nMATE\nCinnamon\nDeepin\nEnlightenment\nLXDE\nLXQt\nOpenbox\nFVWM\nHerbstluftWM\nAwesome\nQtile\ndwm\nNotion\nIceWM\nJWM\nBlackbox\nAfterStep\nWindowLab\nXfce\nSugar\nPantheon\nSugar-Desktop\nE16\nE17\nEnlightenment DR17\nMutter\nMarco\nCDE\nPekWM\nWingo\nCompiz\nOrnament\nEXWM\nWayfire\nWay-Cooler\nHypr\nAwesomeWM\nIceWM-Next\nOpenbox-3.6\nXfwm\nRatpoison\nNotionWM\nXMonadContrib\nDWM-Suckless\nQtile3\nLeftWM\nbspwm-git\nherbstluftwm-git\nsway-git\nriver-git\nAmethyst\nChunkWM\nKWin\nMutter-GNOME')

# Partitioning
echo "Launching cfdisk... create partitions (boot + root)."
sleep 2
cfdisk

echo "Available partitions:"
lsblk -pno NAME,SIZE,TYPE | grep part
ask "Select ROOT partition (e.g. /dev/nvme0n1p2)" ROOT_PART
ask "Select BOOT partition (e.g. /dev/nvme0n1p1)" BOOT_PART

# Format and mount
mkfs.ext4 -F "$ROOT_PART"
mkfs.fat -F32 "$BOOT_PART"
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$BOOT_PART" /mnt/boot

# Create /mnt/etc/ for fstab
mkdir -p /mnt/etc/

# ====== Collect user-selected packages ======
USER_PACKAGES=""

# Display manager
case "$DM" in
    gdm) USER_PACKAGES+=" gdm" ;;
    sddm) USER_PACKAGES+=" sddm" ;;
    lightdm) USER_PACKAGES+=" lightdm lightdm-gtk-greeter" ;;
    ly) USER_PACKAGES+=" ly" ;;
esac

# Terminal
case "$TERM" in
    ghostty) USER_PACKAGES+=" ghostty" ;;
    kitty) USER_PACKAGES+=" kitty" ;;
    alacritty) USER_PACKAGES+=" alacritty" ;;
esac

# Kernel selection
KERNEL=$(fzf --height 5 --reverse --prompt "Select Kernel: " \
    --bind "tab:toggle" <<< $'linux-zen\nlinux-bazzite-bin\nnone')

case "$KERNEL" in
    linux-zen) USER_PACKAGES+=" linux-zen" ;;
    linux-bazzite-bin)
        pacman -S --noconfirm git base-devel
        if ! command -v yay >/dev/null 2>&1; then
            cd ~
            git clone https://aur.archlinux.org/yay.git
            cd yay
            makepkg -si --noconfirm
            cd ~
            sudo rm -rf yay
        fi
        USER_PACKAGES+=" linux-bazzite-bin"
        ;;
esac

# DE/WM
USER_PACKAGES+=" $(install_wm "$WM" list_only=true)"

# ====== Install all packages via pacstrap ======
pacstrap -K /mnt $PACKAGES_BASE $USER_PACKAGES

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# ====== Mount /proc, /sys, /dev, /run for chroot ======
mount --types proc /proc /mnt/proc
mount --rbind /sys /mnt/sys
mount --rbind /dev /mnt/dev
mount --rbind /run /mnt/run

# ====== Chroot configuration ======
sudo chroot /mnt /bin/bash <<EOF
set -e

# Locale and keymap
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Hostname
echo "$HOSTNAME" > /etc/hostname

# Root password
echo "root:$ROOTPASS" | chpasswd

# User
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$USERPASS" | chpasswd
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# Enable NetworkManager
systemctl enable NetworkManager

# Enable display manager
case "$DM" in
    gdm) systemctl enable gdm ;;
    sddm) systemctl enable sddm ;;
    lightdm) systemctl enable lightdm ;;
    ly) systemctl enable ly ;;
esac

# Bootloader
bootctl --path=/boot install || echo "bootctl failed, trying efibootmgr"
efibootmgr --create --disk "${BOOT_PART%p*}" --part 1 --label "ArchLinux" --loader /vmlinuz-linux

EOF

echo "Installation complete! You can now reboot."
