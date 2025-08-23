#!/usr/bin/env bash
set -euo pipefail

# Update package database and install required tools
sudo pacman -Sy --noconfirm git fzf

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
ROOT_PART=$(lsblk -lpno NAME --no-tree | grep -E "p[0-9]+$" | fzf --prompt="Root partition: ")

echo "Select boot (EFI) partition:"
BOOT_PART=$(lsblk -lpno NAME --no-tree | grep -E "p[0-9]+$" | fzf --prompt="Boot partition: ")

sudo mkfs.ext4 "$ROOT_PART"
sudo mkfs.fat -F32 "$BOOT_PART"
sudo mount "$ROOT_PART" /mnt
sudo mount --mkdir "$BOOT_PART" /mnt/boot

# Install base packages
sudo pacstrap -K /mnt base base-devel linux-zen linux-firmware sudo nano micro networkmanager grub efibootmgr kitty fastfetch

sudo genfstab -U /mnt >> /mnt/etc/fstab

# Chroot and configure
sudo arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

run_as_user() {
    sudo -u "$USERNAME" bash -c "\$1"
}

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

# Install yay first
run_as_user "cd && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm && cd"

# Display Manager selection
DM=\$(printf "ly\ngdm\nsddm\nlightdm\nlxdm" | fzf --prompt="Select Display Manager: ")
pacman -S --noconfirm "\$DM"
systemctl enable "\$DM"

# Extensive DE/WM list (official repo + popular AUR)
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
xmonad
notion
lumina
cde
pekwm
twm
openbox-xmonad
leftwm-git
dwm-git
qtile-git
xmonad-git
herbstluftwm-git
spectrwm-git
"

WM=\$(echo "\$DE_WM_LIST" | tr ' ' '\n' | fzf --prompt="Select Desktop Environment/Window Manager: ")

# Install selected DE/WM
case "\$WM" in
  minimal) echo "Minimal system selected. No graphical environment installed." ;;
  server) echo "Server installation chosen. Skipping graphical environment." ;;
  *-git|xmonad|notion|lumina|cde|pekwm|openbox-xmonad|dwm)
      run_as_user "yay -S --noconfirm \$WM"
      ;;
  *) pacman -S --noconfirm "\$WM" ;;
esac

# Install VSCodium
run_as_user "yay -S --noconfirm vscodium-bin"

echo "Installation finished. Exit chroot and reboot."
EOF

echo "=== Complete! Please unmount and reboot. ==="
