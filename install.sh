#!/usr/bin/env bash
set -euo pipefail

# Ensure tools are available
pacman -Sy --noconfirm git fzf cfdisk

echo "==== Arch Install Script ===="
read -rp "Hostname: " HOSTNAME
read -rp "Username: " USERNAME
read -rsp "Root password: " ROOTPASS; echo
read -rsp "User password: " USERPASS; echo

# Disk partitioning
echo "Launching cfdisk. Please create root & boot partitions then quit."
lsblk -dpno NAME
DISK=$(lsblk -dpno NAME | fzf --prompt="Select disk for cfdisk: ")
cfdisk "$DISK"

echo "Select root partition:"
ROOT_PART=$(lsblk -lpno NAME | fzf --prompt="Root partition: ")
echo "Select boot (EFI) partition:"
BOOT_PART=$(lsblk -lpno NAME | fzf --prompt="Boot partition: ")

mkfs.ext4 "$ROOT_PART"
mkfs.fat -F32 "$BOOT_PART"
mount "$ROOT_PART" /mnt
mount --mkdir "$BOOT_PART" /mnt/boot

# Install base packages
pacstrap -K /mnt base git fzf linux-zen linux-firmware sudo nano micro networkmanager grub efibootmgr kitty fastfetch

genfstab -U /mnt >> /mnt/etc/fstab

# Chroot and configure
arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

# Locales & Timezone
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc
sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf
echo "KEYMAP=de" > /etc/vconsole.conf
echo "$HOSTNAME" > /etc/hostname

# Root & User
echo "root:$ROOTPASS" | chpasswd
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$USERPASS" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

systemctl enable NetworkManager

# GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Install yay for AUR packages
sudo -u "$USERNAME" bash <<YAYEOF
cd ~
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
YAYEOF

# Display Manager
DM=\$(printf "ly\ngdm\nsddm\nlightdm\nlxdm" | fzf --prompt="Select Display Manager: ")
pacman -S "\$DM"
systemctl enable "\$DM"

# Extensive DE/WM list
DE_WM_LIST="
plasma
gnome
cinnamon
mate
xfce4
budgie-desktop
lxqt
lxde
deepin
enlightenment
pantheon
cutefish
ukui
phosh
cosmic
sugar
minimal
server
i3-wm
i3-gaps
sway
bspwm
hyprland
herbstluftwm
awesome
qtile
leftwm
dwm
spectrwm
ratpoison
openbox
fluxbox
icewm
jwm
blackbox
windowmaker
cwm
afterstep
fvwm
xmonad (AUR)
notion (AUR)
lumina (AUR)
cde (AUR)
pekwm (AUR)
twm (AUR)
openbox-xmonad (AUR)
"
WM=\$(echo "\$DE_WM_LIST" | tr ' ' '\n' | fzf --prompt="Select Desktop Environment/Window Manager: ")

case "\$WM" in
  minimal) echo "Minimal system selected. No graphical environment installed." ;;
  server) echo "Server installation chosen. Skipping graphical environment." ;;
  *"(AUR)") sudo -u "$USERNAME" yay -S --noconfirm "\${WM% (AUR)}-desktop" ;;
  *) pacman -S --noconfirm "\$WM" ;;
esac

# Install VSCodium
sudo -u "$USERNAME" yay -S --noconfirm vscodium-bin

echo "Installation finished. Exit chroot and reboot."
EOF

echo "=== Complete! Please unmount and reboot. ==="
