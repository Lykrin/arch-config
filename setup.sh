#!/bin/bash
set -euo pipefail

RED='\\u001B[0;31m'
GREEN='\\u001B[0;32m'
YELLOW='\\u001B[0;33m'
NC='\\u001B[0m'
INSTLOG="install.log"

print_message() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

prompt_user() {
    local prompt=$1
    echo -en "${YELLOW}${prompt}${NC} (Y/n) "
    read -r response
    if [[ "$response" =~ ^[Nn]$ ]]; then
        return 1
    fi
    return 0
}

update_yay() {
    yay -Syu --noconfirm "${@:-}" 2>&1 | tee -a "$INSTLOG"
}

install_packages() {
    yay -S --noconfirm --needed "$@" 2>&1 | tee -a "$INSTLOG"
}

extend_sudo_timeout() {
    print_message "$YELLOW" "Extending sudo session timeout..."
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}

cleanup() {
    jobs -p | xargs -r kill 2>/dev/null
}

trap cleanup EXIT INT TERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

if pacman -Qq base-devel &>/dev/null; then
    print_message "$GREEN" "Base Devel located, moving on."
else
    print_message "$RED" "Base Devel is required for this script. Exiting..."
    exit 1
fi

extend_sudo_timeout

if command -v yay &>/dev/null; then
    print_message "$GREEN" "Yay located, updating system."
    update_yay
else
    print_message "$RED" "Yay not found."
    if prompt_user "Would you like to install yay?"; then
        [ -d "yay" ] && rm -rf yay
        git clone https://aur.archlinux.org/yay.git 2>> "$INSTLOG"
        (cd yay && makepkg -si --noconfirm 2>> "$INSTLOG")
        rm -rf yay
        update_yay --sudoloop
    else
        print_message "$RED" "Yay is required for this script. Exiting..."
        exit 1
    fi
fi

if prompt_user "Would you like to install the packages?"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting package installation" | tee -a "$INSTLOG"

    # Base dependencies for building
    base_deps=(cmake ninja meson wayland-protocols libxcb xcb-proto xcb-util xcb-util-keysyms
               libxfixes libx11 libxcomposite xorg-xinput libxrender pixman libdrm libxkbcommon
               xcb-util-wm xorg-xwayland glslang qt6-wayland pugixml)
    install_packages "${base_deps[@]}"

    # Audio stack
    audio_deps=(pipewire pipewire-pulse pipewire-alsa pipewire-jack pipewire-audio
                lib32-pipewire lib32-pipewire-jack wireplumber noise-suppression-for-voice)
    install_packages "${audio_deps[@]}"

    # Hyprland core libraries (0.53+ requirements)
    hypr_packages=(hyprutils hyprlang hyprwayland-scanner hyprland-protocols
                  hyprgraphics hyprcursor hyprwire aquamarine 
                  hyprland-guiutils muparser re2 glaze hyprland)
    install_packages "${hypr_packages[@]}"

    # Hyprland ecosystem utilities
    hypr_utils=(hypridle hyprlock hyprpaper hyprpolkitagent xdg-desktop-portal-hyprland)
    install_packages "${hypr_utils[@]}"

    # Session management (UWSM is now optional but recommended)
    install_packages uwsm

    # Other tools and applications
    other_packages=(fish waybar iwd ffmpeg ffmpegthumbnailer wf-recorder ydotool grimblast-git 
                    neovim foot foot-terminfo nemo nemo-fileroller gvfs gvfs-mtp fuzzel 
                    pavucontrol cliphist wl-clipboard wttrbar mpv btop vivaldi vesktop fprintd 
                    cava dunst pamixer brightnessctl catppuccin-gtk-theme-mocha sweet-folders-icons-git 
                    xdg-user-dirs fastfetch ladspa noto-fonts-cjk ttf-firacode-nerd noto-fonts 
                    noto-fonts-emoji steam ttf-nerd-fonts-symbols-common otf-firamono-nerd qt5-wayland 
                    qt6-wayland mkinitcpio-firmware ib-tws nwg-look bolt-launcher bibata-cursor-theme-bin 
                    gnome-themes-extra qt5ct qt6ct ripgrep xdg-desktop-portal xdg-desktop-portal-gtk 
                    qbittorrent-enhanced xsettingsd breeze-icons jre11-openjdk libva lib32-vulkan-mesa-layers 
                    libvdpau-va-gl)
    install_packages "${other_packages[@]}"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Package installation completed" | tee -a "$INSTLOG"
    
    # Verify critical packages
    for pkg in hyprland fish foot hyprutils aquamarine; do
        if ! pacman -Qq "$pkg" &>/dev/null; then
            print_message "$RED" "Critical package $pkg failed to install!"
        fi
    done
fi

if prompt_user "Would you like to set Fish as your default shell?"; then
    print_message "$GREEN" "Setting Fish as default shell..."
    if ! grep -q "/usr/bin/fish" /etc/shells; then
        echo "/usr/bin/fish" | sudo tee -a /etc/shells
    fi
    sudo chsh -s /usr/bin/fish "$USER"
    print_message "$GREEN" "Fish shell set as default. Changes take effect after logout/login."
fi

if prompt_user "Would you like to copy configuration files?"; then
    if [ ! -d ".config" ] && [ ! -d "wallpapers" ] && [ ! -d ".icons" ]; then
        print_message "$RED" "No configuration directories found in current directory"
    else
        print_message "$GREEN" "Copying configuration files..."
        mkdir -p ~/.config ~/.icons

        if [ -d ".config" ]; then
            cp -R .config/* ~/.config/
            print_message "$GREEN" "Copied .config files"
        fi

        if [ -d "wallpapers" ]; then
            cp -R wallpapers ~/
            print_message "$GREEN" "Copied wallpapers"
        fi

        if [ -d ".icons" ]; then
            cp -R .icons/* ~/.icons/
            print_message "$GREEN" "Copied .icons files"
        fi

        if [ -f "loader.conf" ]; then
            sudo cp -f loader.conf /boot/loader/
            print_message "$GREEN" "Copied loader.conf"
        fi

        if [ -f "vconsole.conf" ]; then
            sudo cp -f vconsole.conf /etc/
            print_message "$GREEN" "Copied vconsole.conf"
        fi

        if [ -f "mkinitcpio.conf" ]; then
            sudo cp -f mkinitcpio.conf /etc/
            print_message "$GREEN" "Copied mkinitcpio.conf"
        fi

        if [ -f "locale.gen" ]; then
            sudo cp -f locale.gen /etc/
            print_message "$GREEN" "Copied locale.gen"
        fi

        [ -d ~/.config/waybar/scripts ] && chmod +x ~/.config/waybar/scripts/*
        [ -f ~/.config/hypr/xdg-portal-hyprland ] && chmod +x ~/.config/hypr/xdg-portal-hyprland

        print_message "$GREEN" "Configuration files copied successfully"
    fi
fi

if prompt_user "Would you like to set up silent boot for zen kernel?"; then
    print_message "$GREEN" "Setting up silent boot for zen kernel..."
    zen_conf=$(find /boot/loader/entries/ -name '*linux-zen.conf' -print -quit)
    if [ -n "$zen_conf" ]; then
        sudo sed -i.bak '/^options/ s/$/ quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3/' "$zen_conf"
        print_message "$GREEN" "Silent boot configured for zen kernel"
    else
        print_message "$YELLOW" "No zen kernel entry found"
    fi
fi

if prompt_user "Would you like to create the udev rule for ydotool (uinput)?"; then
    print_message "$GREEN" "Creating udev rule for ydotool..."
    sudo install -D -m 0644 /dev/stdin /etc/udev/rules.d/70-ydotool-uinput.rules <<'EOF'
KERNEL=="uinput", GROUP="input", MODE="0660"
EOF
    sudo udevadm control --reload
    sudo udevadm trigger -s input
    print_message "$GREEN" "udev rule installed and applied."
fi

if prompt_user "Would you like to install Kickstart Neovim config?"; then
    print_message "$GREEN" "Installing Kickstart Neovim config..."
    if [ -d ~/.config/nvim ]; then
        if [ -d ~/.config/nvim/.git ]; then
            rm -rf ~/.config/nvim
        else
            mv ~/.config/nvim ~/.config/nvim.backup.$(date +%Y%m%d_%H%M%S)
        fi
    fi
    git clone https://github.com/lykrin/kickstart.nvim.git ~/.config/nvim
fi

if prompt_user "Would you like to regenerate locale?"; then
    print_message "$GREEN" "Regenerating locale..."
    sudo locale-gen
    print_message "$GREEN" "Locale generated"
fi

if prompt_user "Would you like to add user to input group?"; then
    if ! groups "$USER" | grep -q '\\binput\\b'; then
        sudo gpasswd -a "$USER" input
        print_message "$GREEN" "User added to input group"
    else
        print_message "$YELLOW" "User already in input group"
    fi
fi

# GTK/Qt theming
if command -v gsettings &>/dev/null && [ -n "${DISPLAY:-${WAYLAND_DISPLAY:-}}" ]; then
    print_message "$GREEN" "Applying GTK theme settings..."
    gsettings set org.gnome.desktop.interface gtk-theme "catppuccin-mocha-teal-standard+default"
    gsettings set org.gnome.desktop.wm.preferences theme "catppuccin-mocha-teal-standard+default"
    gsettings set org.gnome.desktop.interface icon-theme "Breeze-Dark"
    gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
fi

# Rebuild initramfs if mkinitcpio.conf was copied
if [ -f "mkinitcpio.conf" ] && [ -f /etc/mkinitcpio.conf ]; then
    if prompt_user "Would you like to rebuild initramfs now?"; then
        print_message "$GREEN" "Rebuilding initramfs..."
        sudo mkinitcpio -P
    fi
fi

print_message "$GREEN" "Script completed successfully!"
print_message "$YELLOW" "Important notes:"
print_message "$YELLOW" "- Fish shell is now your default shell (effective after logout/login)"
print_message "$YELLOW" "- UWSM configuration is included in your .config files"
print_message "$YELLOW" "- Hyprland will auto-start on TTY1 login with UWSM"
print_message "$YELLOW" "- Silent boot is configured for zen kernel"
print_message "$YELLOW" "- Add 'uwsm finalize' to your Fish config for proper session management"
print_message "$YELLOW" "- Make sure to reboot if you updated mkinitcpio.conf or locale settings"

if prompt_user "Would you like to reboot now to apply all changes?"; then
    sudo reboot
fi
