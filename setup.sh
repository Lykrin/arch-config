#!/bin/bash

# Define ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

INSTLOG="install.log"

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to prompt user
prompt_user() {
    local prompt=$1
    echo -en "${YELLOW}${prompt}${NC} (Y/n) "
    read -n1 -r response
    echo  # move to a new line
    [[ $response != "N" && $response != "n" ]]
}

# Check for Base Devel
if pacman -Q | grep -q base-devel; then
    print_message "$GREEN" "Base Devel was located, moving on."
else
    print_message "$RED" "Base Devel is required for this script, now exiting"
    exit 1
fi

# Check for yay
if [ -f "/sbin/yay" ]; then 
    print_message "$GREEN" "Yay was located, moving on."
    yay -Syu
else 
    print_message "$RED" "Yay was NOT located"
    if prompt_user "Would you like to install yay?"; then
        git clone https://aur.archlinux.org/yay.git &>> $INSTLOG
        (cd yay && makepkg -si --noconfirm) &>> $INSTLOG
        rm -rf yay
        yay -Syu --noconfirm
    else
        print_message "$RED" "Yay is required for this script, now exiting"
        exit 1
    fi
fi

# Install needed packages
if prompt_user "Would you like to install the packages?"; then
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting package installation"
        yay -S --noconfirm --needed --overwrite "/usr/lib/libjack*" -i \
        pipewire pipewire-pulse pipewire-alsa pipewire-jack lib32-pipewire-jack \
        lib32-pipewire wireplumber noise-suppression-for-voice pipewire-audio \
        zsh zsh-antidote hyprland waybar hypridle hyprlock hyprpaper \
        xdg-desktop-portal-hyprland polkit-gnome networkmanager-dmenu-git \
        network-manager-applet ffmpeg ffmpegthumbnailer wf-recorder grimblast-git \
        neovim foot foot-terminfo nemo nemo-fileroller gvfs gvfs-mtp \
        fuzzel bolt-launcher pavucontrol cliphist wl-clipboard clapper wttrbar \
        viewnior btop brave-bin vesktop mkinitcpio-firmware fprintd cava \
        nwg-look-bin dunst pamixer brightnessctl motivewave sweet-gtk-theme \
        sweet-folders-icons-git xdg-user-dirs fastfetch ladspa LADSPA \
        ttf-firacode-nerd noto-fonts noto-fonts-emoji ttf-nerd-fonts-symbols-common \
        otf-firamono-nerd qt5-wayland qt6-wayland \
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Package installation completed"
    } 2>&1 | tee -a install.log
fi

# Copy .config files
if prompt_user "Would you like to copy .config files?"; then
    print_message "$GREEN" "Copying .config files..."
    cp -R .config/* ~/.config/
    cp -R wallpapers ~/
    cp -R .icons ~/
    cp -R .zshenv ~/
    chmod +x ~/.config/waybar/scripts/* ~/.config/hypr/xdg-portal-hyprland
fi

# Install NVChad
if prompt_user "Would you like to install Kickstart?"; then
    print_message "$GREEN" "Installing Kickstart..."
    git clone https://github.com/lykrin/kickstart.nvim.git "${XDG_CONFIG_HOME:-$HOME/.config}"/nvim
fi

# Set zsh as default shell
chsh -s /bin/zsh

# Script completion
print_message "$GREEN" "Script has completed. Remember to set NM and quiet boot"
print_message "$GREEN" "You can start Hyprland by typing Hyprland (note the capital H)."

# Prompt for reboot
if prompt_user "Would you like to reboot?"; then
    reboot
fi
