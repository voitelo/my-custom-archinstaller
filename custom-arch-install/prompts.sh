#!/usr/bin/env bash
set -euo pipefail

ask_hostname() {
    read -rp "Enter hostname: " HOST
    echo "$HOST"
}

ask_username() {
    read -rp "Enter username: " USER
    echo "$USER"
}

ask_password() {
    read -rsp "Enter user password: " PASS; echo
    echo "$PASS"
}

ask_root_password() {
    read -rsp "Enter root password: " PASS; echo
    echo "$PASS"
}

ask_display_manager() {
    echo -e "sddm\nlightdm\nly\nnone" | fzf --height 10 --reverse --prompt "Select Display Manager: "
}

ask_terminal() {
    echo -e "kitty\nalacritty\nghostty" | fzf --height 10 --reverse --prompt "Select Terminal: "
}

ask_de_wm() {
    echo -e "minimal\nserver\nhyprland\nherbstluftwm\nkde\ngnome\nbudgie\nbspwm\ni3wm\nxmonad\nriver\nsway\ncosmic\nlumina\nmate\nxfce\nlxqt\nenlightenment\nawesome\ndwm" |
        fzf --height 20 --reverse --prompt "Select DE/WM: "
}

ask_kernel() {
    echo -e "linux-zen\nlinux-bazzite-bin" | fzf --height 5 --reverse --prompt "Select Kernel: "
}

ask_disk_partition() {
    read -rp "Enter disk (e.g., /dev/sda): " DISK
    echo "$DISK"
}

ask_boot_partition() {
    read -rp "Enter boot partition (e.g., /dev/sda1): " BOOT
    echo "$BOOT"
}

ask_root_partition() {
    read -rp "Enter root partition (e.g., /dev/sda2): " ROOT
    echo "$ROOT"
}

ask_efi_part_number() {
    read -rp "Enter EFI partition number (detected default is $1, press Enter to accept): " EFI
    echo "${EFI:-$1}"
}

ask_efi_label() {
    read -rp "Enter EFI boot entry label (default 'Arch Linux'): " LABEL
    echo "${LABEL:-Arch Linux}"
}
