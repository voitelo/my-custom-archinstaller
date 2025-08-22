#!/usr/bin/env bash
set -euo pipefail

source ./prompts.sh
source ./wm.sh

# Ensure tools
pacman -Sy --noconfirm fzf git base-devel

# Ask all questions
HOSTNAME=$(ask_hostname)
USERNAME=$(ask_username)
PASSWORD=$(ask_password)
ROOT_PASSWORD=$(ask_root_password)
DISPLAY_MANAGER=$(ask_display_manager)
TERMINAL=$(ask_terminal)
DE_WM=$(ask_de_wm)
KERNEL=$(ask_kernel)
DISK_DEV=$(ask_disk_partition)
BOOT_PART=$(ask_boot_partition)
ROOT_PART=$(ask_root_partition)

# Detect EFI partition number dynamically
EFI_PART_NUM=$(echo "$BOOT_PART" | grep -o '[0-9]*$' || echo "1")
EFI_PART_NUM=$(ask_efi_part_number "$EFI_PART_NUM")
EFI_LABEL=$(ask_efi_label)

# Partition formatting
mkfs.fat -F32 "$BOOT_PART"
mkfs.ext4 "$ROOT_PART"

mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$BOOT_PART" /mnt/boot
mkdir -p /mnt/etc

# Packages
PACKAGES_BASE="base base-devel linux-firmware sudo fastfetch efibootmgr networkmanager grub"
PACKAGES_KERNEL="$KERNEL"

PACKAGES_DM=""
case "$DISPLAY_MANAGER" in
    sddm) PACKAGES_DM="sddm" ;;
    lightdm) PACKAGES_DM="lightdm lightdm-gtk-greeter" ;;
    ly) PACKAGES_DM="ly" ;;
esac

PACKAGES_TERM=""
case "$TERMINAL" in
    kitty) PACKAGES_TERM="kitty" ;;
    alacritty) PACKAGES_TERM="alacritty" ;;
    ghostty) PACKAGES_TERM="ghostty" ;;
esac

PACKAGES_WM=$(get_wm_packages "$DE_WM")
ALL_PACKAGES="$PACKAGES_BASE $PACKAGES_KERNEL $PACKAGES_DM $PACKAGES_TERM $PACKAGES_WM"

echo "Installing packages: $ALL_PACKAGES"
pacstrap -K /mnt $ALL_PACKAGES

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot for configuration
sudo chroot /mnt /bin/bash <<EOF
set -euo pipefail

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
echo "$HOSTNAME" > /etc/hostname

echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf

echo "root:$ROOT_PASSWORD" | chpasswd
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/wheel

systemctl enable NetworkManager
[ "$DISPLAY_MANAGER" = "sddm" ] && systemctl enable sddm
[ "$DISPLAY_MANAGER" = "lightdm" ] && systemctl enable lightdm
[ "$DISPLAY_MANAGER" = "ly" ] && systemctl enable ly

# Install GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id="$EFI_LABEL" --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# Create EFI boot entry
efibootmgr --create --disk "$DISK_DEV" --part "$EFI_PART_NUM" --label "$EFI_LABEL" --loader "\EFI\\$EFI_LABEL\\grubx64.efi" || true

# Yay inside chroot
cd /home/$USERNAME
sudo -u "$USERNAME" git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u "$USERNAME" makepkg -si --noconfirm
cd ..
rm -rf yay
EOF

echo "Installation complete. Reboot to start your new system."
