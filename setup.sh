e#!/bin/bash
# Define ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

#   Check for Base Devel
if pacman -Q | grep -q base-devel; then
    echo -e "${GREEN}Base Devel was located, moving on.${NC}"
else
    echo -e "${RED}Base Devel is required for this script, now exiting${NC}"
    exit
fi

# Check for yay
ISYAY=/sbin/yay
INSTLOG="install.log"
if [ -f "$ISYAY" ]; then 
    echo -e "${GREEN}Yay was located, moving on.${NC}"
    yay -Suy
else 
    echo -e "${RED}Yay was NOT located${NC}"
    read -n1 -rep $'[\e[1;33mACTION\e[0m] - Would you like to install yay (y,n) ' INSTYAY
    if [[ $INSTYAY == "Y" || $INSTYAY == "y" ]]; then
        git clone https://aur.archlinux.org/yay.git &>> $INSTLOG
        cd yay
        makepkg -si --noconfirm &>> ../$INSTLOG
        cd ..
        rm -rf yay
    else
        echo -e "${RED}Yay is required for this script, now exiting${NC}"
        exit
    fi
fi

#   Install all needed packages
read -n1 -rep 'Would you like to install the packages? (y,n)' INST
if [[ $INST == "Y" || $INST == "y" ]]; then
    yay -R --noconfirm swaylock waybar
    yay -S --noconfirm zsh hyprland-git polkit-gnome ffmpeg fastfetch neovim viewnior \
    rofi-lbonn-wayland pavucontrol thunar starship cliphist wl-clipboard \
    wf-recorder swww waypaper grimblast-git ffmpegthumbnailer tumbler gvfs \
    playerctl noise-suppression-for-voice file-roller thunar-archive-plugin \
    thunar-media-tags-plugin kitty thunar-volman gvfs-mtp brave-bin vesktop \
    waybar-git wlogout  swaylock-effects pamixer papirus-icon-theme \
    nwg-look-bin dunst ttf-firacode-nerd noto-fonts qt5-wayland qt6-wayland\
    noto-fonts-emoji ttf-nerd-fonts-symbols-common otf-firamono-nerd \
    brightnessctl hyprpicker-git pipewire lib32-pipewire wireplumber \
    pipewire-audio pipewire-pulse pipewire-alsa pipewire-jack \
    lib32-pipewire-jack xdg-user-dirs xdg-desktop-portal-hyprland catppuccin-gtk-theme-mocha --needed
fi

#  Copy .config files
read -n1 -rep 'Would you like to copy .config files? (y,n)' CFG
if [[ $CFG == "Y" || $CFG == "y" ]]; then
    echo -e "Copying .config files...\n"
    cp -R .config/* ~/.config/
    # set as executable
    chmod +x ~/.config/waybar/scripts/*
    chmod +x ~/.config/hypr/xdg-portal-hyprland
fi

#   Copy .zshrc
read -n1 -rep 'Would you like to copy .zshrc? (y,n)' ZSH
if [[ $ZSH == "Y" || $ZSH == "y" ]]; then
    echo -e "Copying .zshrc...\n"
    cp .zshrc ~/
fi

#   Install NVChad
read -n1 -rep 'Would you like to install NVChad? (y,n)' NVCHAD
if [[ $NVCHAD == "Y" || $NVCHAD == "y" ]]; then
    echo -e "Installing NVChad...\n"
    git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1
fi

# install oh-my-zsh
read -n1 -rep 'Would you like to install oh-my-zsh? (y,n)' ZSH
if [[ $ZSH == "Y" || $ZSH == "y" ]]; then
    echo -e "Installing oh-my-zsh...\n"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

#   Script is done
echo -e "Script had completed. Remember to set wifi service up. https://wiki.archlinux.org/title/Lenovo_ThinkPad_T14s_(AMD)_Gen_3 \n"
echo -e "You can start Hyprland by typing Hyprland (note the capital H).\n"
read -n1 -rep 'Would you like to reboot? (y,n)' HYP
if [[ $HYP == "Y" || $HYP == "y" ]]; then
    reboot
else
    exit
fi
