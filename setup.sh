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
    yay -S --noconfirm --needed \
        zsh hyprland-git polkit-gnome ffmpeg fastfetch neovim viewnior bolt-launcher \
        fuzzel pavucontrol zsh-antidote cliphist wl-clipboard clapper wttrbar \
        wf-recorder hyprpaper grimblast-git ffmpegthumbnailer btop gvfs vesktop \
        foot foot-terminfo nemo nemo-fileroller gvfs-mtp brave-bin mkinitcpio-firmware \
        waybar-git hypridle hyprlock pamixer sweet-folders-icons-git fprintd LADSPA \
        nwg-look-bin dunst ttf-firacode-nerd noto-fonts qt5-wayland qt6-wayland \
        noto-fonts-emoji ttf-nerd-fonts-symbols-common otf-firamono-nerd networkmanager-dmenu-git \
        brightnessctl pipewire noise-suppression-for-voice lib32-pipewire wireplumber \
        pipewire-audio pipewire-pulse pipewire-alsa pipewire-jack ladspa motivewave \
        lib32-pipewire-jack xdg-user-dirs xdg-desktop-portal-hyprland sweet-gtk-theme \
        network-manager-applet cava
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
if prompt_user "Would you like to install LVIM?"; then
    print_message "$GREEN" "Installing LVIM..."
    LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh)
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
