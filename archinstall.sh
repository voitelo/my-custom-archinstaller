#!/usr/bin/env bash

sudo pacman -Sy --noconfirm fzf

set -euo pipefail

# Colors
RESET="\033[0m"
INFO="\033[1;34m"
ROOT="\033[1;31m"
OK="\033[1;32m"
WARN="\033[1;33m"
WM="\033[1;35m"
DE="\033[1;36m"

echo -e "${INFO}[INFO] Starting Arch installation script...${RESET}"

cat <<'EOF'

 _______________________________________
< WELCOME TO MY ARCHINSTALL SCRIPT BRO! >
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

# --- User input ---
read -rp "$(echo -e "${INFO}Enter hostname:${RESET} ")" HOSTNAME
read -rp "$(echo -e "${INFO}Enter username:${RESET} ")" USERNAME
read -rp "$(echo -e "${INFO}Enter root password (will be visible):${RESET} ")" ROOT_PASS
read -rp "$(echo -e "${INFO}Enter user password (will be visible):${RESET} ")" USER_PASS
read -rp "$(echo -e "${INFO}Enter additional packages (comma-separated, optional):${RESET} ")" EXTRA_PKGS

# Replace commas with spaces, default to empty string if nothing entered
EXTRA_PKGS="${EXTRA_PKGS//,/ }"

# --- Filesystem selection ---
FS=$(printf "ext4\nbtrfs\nzfs\n" | fzf --prompt="Select filesystem: ")

ROOT_FORMAT=""
case "$FS" in
  ext4)
    ROOT_FORMAT="mkfs.ext4"
    ;;
  btrfs)
    ROOT_FORMAT="mkfs.btrfs -f"
    ;;
  zfs)
    ROOT_FORMAT=""  # handled in chroot
    ;;
  *)
    echo -e "${ROOT}Invalid filesystem selected.${RESET}"
    exit 1
    ;;
esac

# --- Partitioning ---
echo -e "${INFO}[INFO] Starting partitioning...${RESET}"
cfdisk

BOOT_PART=$(lsblk -lpno NAME | fzf --prompt="Select boot partition: ")
ROOT_PART=$(lsblk -lpno NAME | fzf --prompt="Select root partition: ")

echo -e "${WARN}Formatting boot partition...${RESET}"
mkfs.fat -F32 "$BOOT_PART"

if [[ "$FS" != "zfs" && -n "$ROOT_FORMAT" ]]; then
    echo -e "${WARN}Formatting root partition as $FS...${RESET}"
    $ROOT_FORMAT "$ROOT_PART"
fi

echo -e "${INFO}Mounting partitions...${RESET}"
mkdir -p /mnt/boot
if [[ "$FS" != "zfs" ]]; then
    mount "$ROOT_PART" /mnt
    mount --mkdir "$BOOT_PART" /mnt/boot
fi

# --- Optional ZRAM ---
read -rp "$(echo -e "${INFO}Do you want to enable ZRAM? (y/N):${RESET} ")" ZRAM_ANSWER
ENABLE_ZRAM=false
if [[ "${ZRAM_ANSWER:-}" =~ ^[Yy]$ ]]; then
    ENABLE_ZRAM=true
fi

# --- Kernel selection ---
KERNEL=$(printf "linux\nlinux-lts\nlinux-zen\nlinux-hardened\n" | fzf --prompt="Select kernel to install: ")

# --- Bootloader selection ---
BOOTLOADER=$(printf "GRUB\nsystemd-boot\nrEFInd\nefistub\n" | fzf --prompt="Select bootloader: ")

# --- Display Manager choice ---
DM=$(printf "ly\nlxdm\ngdm\nlightdm\nsddm\n" | fzf --prompt="Select display manager: ")

# --- Base system installation ---
echo -e "${ROOT}[ROOT] Installing base system...${RESET}"

BASE_PKGS="base base-devel $KERNEL linux-firmware pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse networkmanager $DM grub efibootmgr fzf git sudo"
[[ "$FS" = "zfs" ]] && BASE_PKGS="$BASE_PKGS zfs-dkms zfs-utils"
$ENABLE_ZRAM && BASE_PKGS="$BASE_PKGS systemd-zram-generator"

pacstrap -K /mnt $BASE_PKGS

# --- Generate fstab ---
echo -e "${INFO}[INFO] Generating fstab...${RESET}"
genfstab -U /mnt >> /mnt/etc/fstab

# --- Chroot configuration ---
arch-chroot /mnt bash <<EOF
set -euo pipefail

# Hostname, locale, keyboard
echo "$HOSTNAME" > /etc/hostname
sed -i 's/#en_GB.UTF-8/en_GB.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf
echo "KEYMAP=de" > /etc/vconsole.conf

# Root & user password
echo "root:$ROOT_PASS" | chpasswd
useradd -m -G wheel "$USERNAME"
echo "$USERNAME:$USER_PASS" | chpasswd
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

systemctl enable NetworkManager
systemctl enable "$DM"

# ZFS setup
if [[ "$FS" = "zfs" ]]; then
    echo "[INFO] Creating ZFS pool..."
    zpool create -f rpool "$ROOT_PART"
    zfs create rpool/root
    mount -t zfs rpool/root /mnt
fi

# Optional ZRAM
if [[ "$ENABLE_ZRAM" = true ]]; then
    echo "[INFO] Setting up ZRAM..."
    cat > /etc/systemd/zram-generator.conf <<ZZ
[zram0]
zram-size = ram/2
compression-algorithm = zstd
max-zram-streams = 4
swap-priority = 100
ZZ
    systemctl enable systemd-zram-setup@zram0.service || true
fi

# Bootloader installation
case "$BOOTLOADER" in
    GRUB)
        echo "[INFO] Installing GRUB..."
        grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
        grub-mkconfig -o /boot/grub/grub.cfg
        ;;
    systemd-boot)
        bootctl install
        echo "default $KERNEL" > /boot/loader/loader.conf
        ;;
    rEFInd)
        pacman -S --noconfirm refind
        refind-install
        ;;
    efistub)
        echo "[INFO] EFI stub selected; no bootloader installed."
        ;;
esac
EOF

# --- Install yay & additional packages ---
arch-chroot /mnt bash <<EOF
su - "$USERNAME" -c "git clone https://aur.archlinux.org/yay.git ~/yay && cd ~/yay && makepkg -si --noconfirm"
EOF

if [[ -n "${EXTRA_PKGS:-}" ]]; then
    echo -e "${INFO}[INFO] Installing additional packages: $EXTRA_PKGS${RESET}"
    arch-chroot /mnt bash <<EOF
su - "$USERNAME" -c "yay --noconfirm -S $EXTRA_PKGS"
EOF
fi

# --- DE/WM selection ---
DEWM_LIST="GNOME COSMIC Pantheon Budgie Cinnamon MATE Deepin Hyprland Sway River Wayfire Labwc Niri Hikari Velox Dwl"

echo -e "${INFO}[INFO] Select DE/WM to install...${RESET}"
SELECTED=$(echo -e "$DEWM_LIST" | fzf --multi)

if [[ -n "${SELECTED:-}" ]]; then
    arch-chroot /mnt bash <<EOF
su - "$USERNAME" -c "yay --noconfirm -S $SELECTED"
EOF
fi

echo -e "${OK}[OK] Installation complete. You can now reboot.${RESET}"
