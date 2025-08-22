#!/usr/bin/env bash
set -euo pipefail

get_wm_packages() {
    case "$1" in
        minimal) echo "" ;;
        server) echo "" ;;
        hyprland) echo "hyprland waybar" ;;
        herbstluftwm) echo "herbstluftwm" ;;
        kde) echo "plasma kde-applications" ;;
        gnome) echo "gnome" ;;
        budgie) echo "budgie-desktop" ;;
        bspwm) echo "bspwm sxhkd" ;;
        i3wm) echo "i3-gaps" ;;
        xmonad) echo "xmonad xmonad-contrib xmobar" ;;
        river) echo "river" ;;
        sway) echo "sway waybar" ;;
        cosmic) echo "cosmic-desktop" ;;
        lumina) echo "lumina" ;;
        mate) echo "mate mate-extra" ;;
        xfce) echo "xfce4 xfce4-goodies" ;;
        lxqt) echo "lxqt" ;;
        enlightenment) echo "enlightenment" ;;
        awesome) echo "awesome" ;;
        dwm) echo "dwm dmenu st" ;;
        *) echo "" ;;
    esac
}
