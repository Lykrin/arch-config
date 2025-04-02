#!/bin/bash
set -euo pipefail

# Define ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'  # No Color
INSTLOG="install.log"

# Function to print colored messages
print_message() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Function to prompt user; returns 0 for yes and 1 for no
prompt_user() {
    local prompt=$1
    echo -en "${YELLOW}${prompt}${NC} (Y/n) "
    read -n1 -r response
    echo    # Move to new line
    if [[ "$response" =~ ^[Nn]$ ]]; then
        return 1
    fi
    return 0
}

# Function to update packages using yay
update_yay() {
    yay -Syu --noconfirm "${@:-}" 2>&1 | tee -a "$INSTLOG"
}

# Function to install a batch of packages
install_packages() {
    local options=("$@")
    # The caller should supply options and then the list of packages
    yay -S --noconfirm --needed "${options[@]}" 2>&1 | tee -a "$INSTLOG"
}

# Ensure required dependencies are available
if pacman -Qq base-devel &>/dev/null; then
    print_message "$GREEN" "Base Devel located, moving on."
else
    print_message "$RED" "Base Devel is required for this script. Exiting..."
    exit 1
fi

# Check for yay using command -v; install if missing
if command -v yay &>/dev/null; then
    print_message "$GREEN" "Yay located, updating system."
    update_yay
else
    print_message "$RED" "Yay not found."
    if prompt_user "Would you like to install yay?"; then
        git clone https://aur.archlinux.org/yay.git 2>> "$INSTLOG"
        (cd yay && makepkg -si --noconfirm 2>> "$INSTLOG")
        rm -rf yay
        update_yay --sudoloop
    else
        print_message "$RED" "Yay is required for this script. Exiting..."
        exit 1
    fi
fi

# Install packages if confirmed by user
if prompt_user "Would you like to install the packages?"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting package installation" | tee -a "$INSTLOG"
    
    # Base dependencies
    base_deps=(cmake ninja meson wayland-protocols libxcb xcb-proto xcb-util xcb-util-keysyms
               libxfixes libx11 libxcomposite xorg-xinput libxrender pixman libdrm libxkbcommon
               xcb-util-wm xorg-xwayland glslang qt6-wayland pugixml)
    install_packages "" "${base_deps[@]}"
    
    # Audio stack
    audio_deps=(pipewire pipewire-pulse pipewire-alsa pipewire-jack pipewire-audio
                lib32-pipewire lib32-pipewire-jack wireplumber noise-suppression-for-voice)
    install_packages "" "${audio_deps[@]}"
    
    # Git packages with overwrite option
    git_packages=(hyprutils-git hyprlang-git hyprwayland-scanner-git hyprland-protocols-git
                  hyprgraphics-git hyprland-qt-support-git hyprland-qtutils-git hyprcursor-git
                  aquamarine-git hyprland-git)
    install_packages "--overwrite='*'"" "${git_packages[@]}"
    
    # Additional utilities with overwrite option
    additional_utils=(hypridle-git hyprlock-git hyprpaper-git hyprpolkitagent-git
                      xdg-desktop-portal-hyprland-git)
    install_packages "--overwrite='*'"" "${additional_utils[@]}"
    
    # Rest of the packages
    other_packages=(fish waybar networkmanager-dmenu network-manager-applet ffmpeg ffmpegthumbnailer
                    wf-recorder grimblast-git uwsm neovim foot foot-terminfo nemo nemo-fileroller
                    gvfs gvfs-mtp fuzzel pavucontrol cliphist wl-clipboard clapper wttrbar viewnior
                    btop vivaldi vesktop fprintd cava dunst pamixer brightnessctl sweet-gtk-theme
                    sweet-folders-icons-git xdg-user-dirs fastfetch ladspa ttf-firacode-nerd noto-fonts
                    noto-fonts-emoji steam ttf-nerd-fonts-symbols-common otf-firamono-nerd qt5-wayland
                    qt6-wayland motivewave mkinitcpio-firmware ib-tws nwg-look bolt-launcher bibata-cursor-theme-bin
                    gnome-themes-extra adwaita-qt5 adwaita-qt6 qt5ct qt6ct)
    install_packages "" "${other_packages[@]}"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Package installation completed" | tee -a "$INSTLOG"
fi

# Copy .config files if requested
if prompt_user "Would you like to copy .config files?"; then
    print_message "$GREEN" "Copying .config files..."
    cp -R .config/* ~/.config/
    cp -R wallpapers ~/
    cp -R .icons ~/
    sudo cp -f loader.conf /boot/loader/
#    sudo cp -f mkinitcpio.conf /etc/
    sudo cp -f vconsole.conf /etc/
#    sudo cp -f motivewave /bin/
    chmod +x ~/.config/waybar/scripts/* ~/.config/hypr/xdg-portal-hyprland
fi

# Setup silent boot if requested
if prompt_user "Would you like to set up silent boot?"; then
    print_message "$GREEN" "Setting up silent boot..."
    sudo find /boot/loader/entries/ -name '*linux-zen.conf' \
      -exec sed -i '/^options/ s/$/ quiet loglevel=2 systemd.show_status=auto rd.udev.log_level=2/' {} +
fi

# Fix display artifacts if requested
if prompt_user "Would you like to fix the Artifacts?"; then
    print_message "$GREEN" "Setting up panel refresh..."
    sudo find /boot/loader/entries/ -name '*linux-zen.conf' \
      -exec sed -i '/^options/ s/$/ amdgpu.dcdebugmask=0x10/' {} +
fi

# Kickstart installation (optional)
if prompt_user "Would you like to install #Kickstart?"; then
    print_message "$GREEN" "Installing #Kickstart..."
    git clone https://github.com/lykrin/kickstart.nvim.git "${XDG_CONFIG_HOME:-$HOME/.config}"/nvim
fi

print_message "$GREEN" "Script has completed. Remember to set NM and quiet boot."
print_message "$GREEN" "You can start Hyprland by typing Hyprland (note the capital H)."

# Prompt for reboot
if prompt_user "Would you like to reboot?"; then
    reboot
fi
