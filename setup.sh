#!/bin/bash

# Define ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
    read -n1 -rep $"${YELLOW}${prompt}${NC} (Y/n) " response
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
        zsh hyprland-git polkit-gnome ffmpeg fastfetch neovim viewnior \
        fuzzel pavucontrol zsh-antidote cliphist wl-clipboard nomacs clapper \
        wf-recorder hyprpaper grimblast-git ffmpegthumbnailer btop gvfs \
        foot foot-terminfo nemo nemo-fileroller gvfs-mtp brave-bin vesktop \
        waybar-git hypridle starship hyprlock pamixer sweet-folders-icons-git LADSPA \
        nwg-look-bin dunst ttf-firacode-nerd noto-fonts qt5-wayland qt6-wayland \
        noto-fonts-emoji ttf-nerd-fonts-symbols-common otf-firamono-nerd \
        brightnessctl pipewire noise-suppression-for-voice lib32-pipewire wireplumber \
        pipewire-audio pipewire-pulse pipewire-alsa pipewire-jack ladspa motivewave \
        lib32-pipewire-jack xdg-user-dirs xdg-desktop-portal-hyprland sweet-gtk-theme
fi

# Copy .config files
if prompt_user "Would you like to copy .config files?"; then
    print_message "$GREEN" "Copying .config files..."
    cp -R .config/* ~/.config/
    chmod +x ~/.config/waybar/scripts/* ~/.config/hypr/xdg-portal-hyprland
fi

# Install NVChad
if prompt_user "Would you like to install NVChad?"; then
    print_message "$GREEN" "Installing NVChad..."
    git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1
fi

# Set zsh as default shell
chsh -s /bin/zsh

# Copy .zshrc and .zsh_plugins.txt
if prompt_user "Would you like to copy .zshrc and .zsh_plugins.txt?"; then
    print_message "$GREEN" "Copying .zshrc and .zsh_plugins.txt..."
    cp .zshrc ~/.zshrc
    cp .zsh_plugins.txt ~/.zsh_plugins.txt
    chmod 644 ~/.zshrc ~/.zsh_plugins.txt
fi

# Script completion
print_message "$GREEN" "Script has completed. Remember to set up wifi service: https://wiki.archlinux.org/title/Lenovo_ThinkPad_T14s_(AMD)_Gen_3"
print_message "$GREEN" "You can start Hyprland by typing Hyprland (note the capital H)."

# Prompt for reboot
if prompt_user "Would you like to reboot?"; then
    reboot
fi
