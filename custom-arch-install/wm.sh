#!/usr/bin/env bash

# Function to return package names for selected DE/WM
install_wm() {
    local choice="$1"
    local list_only="${2:-false}"
    local pkgs=""

    case "$choice" in
        Minimal|Server) pkgs="" ;;
        Hyprland) pkgs="hyprland waybar xdg-desktop-portal-hyprland" ;;
        KDE*|KDE\ Plasma) pkgs="plasma kde-applications" ;;
        GNOME) pkgs="gnome" ;;
        Budgie) pkgs="budgie-desktop" ;;
        BSPWM|bspwm-git) pkgs="bspwm sxhkd" ;;
        i3|i3-gaps) pkgs="i3-gaps" ;;
        Xmonad|XMonadContrib) pkgs="xmonad xmonad-contrib xmobar" ;;
        River|river-git) pkgs="river" ;;
        Sway|sway-git) pkgs="sway" ;;
        Cosmic) pkgs="" ;;
        Lumina) pkgs="lumina" ;;
        MATE) pkgs="mate" ;;
        Cinnamon) pkgs="cinnamon" ;;
        Deepin) pkgs="deepin deepin-extra" ;;
        Enlightenment|E16|E17|Enlightenment\ DR17) pkgs="enlightenment" ;;
        LXDE) pkgs="lxde" ;;
        LXQt) pkgs="lxqt" ;;
        Openbox|Openbox-3.6) pkgs="openbox obconf" ;;
        FVWM) pkgs="fvwm" ;;
        HerbstluftWM|herbstluftwm-git) pkgs="herbstluftwm" ;;
        Awesome|AwesomeWM) pkgs="awesome" ;;
        Qtile|Qtile3) pkgs="qtile" ;;
        dwm|DWM-Suckless) pkgs="dwm" ;;
        Notion|NotionWM) pkgs="notion" ;;
        IceWM|IceWM-Next) pkgs="icewm" ;;
        JWM) pkgs="jwm" ;;
        Blackbox) pkgs="blackbox" ;;
        WindowLab) pkgs="windowlab" ;;
        EXWM) pkgs="emacs-x11" ;;
        LeftWM) pkgs="" ;;
        Amethyst|ChunkWM) pkgs="" ;;
        Xfce) pkgs="xfce4 xfce4-goodies" ;;
        Sugar|Pantheon|Sugar-Desktop) pkgs="" ;;
        Mutter|Marco|CDE|PekWM|Wingo|Compiz|Ornament) pkgs="" ;;
        Wayfire|Way-Cooler|Hypr|AwesomeWM|IceWM-Next|Openbox-3.6|Xfwm|Ratpoison|NotionWM|XMonadContrib|DWM-Suckless|Qtile3|LeftWM|bspwm-git|herbstluftwm-git|sway-git|river-git|KWin|Mutter-GNOME) pkgs="$choice" ;;
        *) echo "Unknown option: $choice" ;;
    esac

    if [ "$list_only" = true ]; then
        echo "$pkgs"
    else
        pacman -S --noconfirm $pkgs
    fi
}
