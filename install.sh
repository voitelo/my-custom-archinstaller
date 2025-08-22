#!/bin/bash
# Ultimate Arch Installer — fully interactive and robust
set -euo pipefail

ask() {
  local prompt="$1"; local default="$2"
  read -rp "$prompt [$default]: " input
  echo "${input:-$default}"
}

choose() {
  local prompt="$1"; shift
  echo "$@" | tr ' ' '\n' | fzf --prompt="$prompt: "
}

echo "=== Custom Arch Installer ==="

# --- User input ---
HOSTNAME=$(ask "Hostname" "arch")
ROOT_PASS=$(ask "Root password" "root")
USERNAME=$(ask "Username" "user")
USER_PASS=$(ask "Password for $USERNAME" "$USERNAME")

LOCALE="en_GB.UTF-8"
KEYMAP="de"
TIMEZONE="Europe/Berlin"

# --- Disk selection and partitioning ---
lsblk
DISK=$(lsblk -dpno NAME,SIZE | fzf --prompt="Select disk for cfdisk: ")
echo "Partitioning with cfdisk. Please create root and boot partitions."
cfdisk "$DISK"

ROOT_PART=$(ask "Enter root partition (e.g., /dev/sda1)" "/dev/sda1")
BOOT_PART=$(ask "Enter boot partition (e.g., /dev/sda2)" "/dev/sda2")

mkfs.ext4 "$ROOT_PART"
mkfs.fat -F32 "$BOOT_PART"

mount "$ROOT_PART" /mnt
mount --mkdir "$BOOT_PART" /mnt/boot

# --- Display Manager selection ---
DM_LIST="gdm sddm lightdm ly lxdm slim nodm"
DM=$(choose "Select display manager" $DM_LIST)

# --- DE/WM selection ---
DE_WM_LIST="
plasma gnome cinnamon mate xfce4 budgie-desktop lxqt lxde deepin enlightenment lumina
i3-wm i3-gaps sway bspwm hyprland herbstluftwm awesome qtile leftwm dwm spectrwm openbox
fluxbox icewm jwm blackbox windowmaker cwm afterstep
"
WM=$(echo "$DE_WM_LIST" | tr ' ' '\n' | fzf --prompt="Select DE/WM: ")

# --- Base installation ---
echo "Installing base system..."
pacstrap /mnt base linux-zen linux-firmware sudo nano micro networkmanager fastfetch kitty grub efibootmgr "$DM" "$WM"

# --- Generate fstab ---
genfstab -U /mnt >> /mnt/etc/fstab

# --- Chroot configuration ---
arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

# Time zone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Locale
sed -i "s/#$LOCALE/$LOCALE/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Keyboard layout
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Hostname and hosts
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<HST
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HST

# Root password
echo "root:$ROOT_PASS" | chpasswd

# Create user and sudo
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$USER_PASS" | chpasswd
sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers

# Enable NetworkManager and DM
systemctl enable NetworkManager
systemctl enable "$DM"

# Install and configure GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Install yay and VSCodium
pacman -S --noconfirm --needed git base-devel
sudo -u $USERNAME bash <<YAY
cd ~
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
yay -S --noconfirm vscodium-bin
YAY

EOF

echo "=== Installation complete! You can reboot now. ==="
