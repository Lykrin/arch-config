#!/bin/bash
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
    yay -Syu
else 
    echo -e "${RED}Yay was NOT located${NC}"
    read -n1 -rep $'[\e[1;33mACTION\e[0m] - Would you like to install yay (Y/n) ' INSTYAY
    if [[ $INSTYAY != "N" && $INSTYAY != "n" ]]; then
        git clone https://aur.archlinux.org/yay.git &>> $INSTLOG
        cd yay
        makepkg -si --noconfirm &>> ../$INSTLOG
        cd ..
        rm -rf yay
        yay -Syu --noconfirm
    else
        echo -e "${RED}Yay is required for this script, now exiting${NC}"
        exit
    fi
fi

#   Install all needed packages
read -n1 -rep $'Would you like to install the packages? (Y/n) ' INST
if [[ $INST != "N" && $INST != "n" ]]; then
    yay -S --noconfirm zsh hyprland-git polkit-gnome ffmpeg fastfetch neovim viewnior \
    fuzzel pavucontrol zsh-antidote cliphist wl-clipboard nomacs clapper \
    wf-recorder hyprpaper grimblast-git ffmpegthumbnailer btop gvfs \
    foot foot-terminfo nemo nemo-fileroller gvfs-mtp brave-bin vesktop \
    waybar-git hypridle starship hyprlock pamixer sweet-folders-icons-git LADSPA \
    nwg-look-bin dunst ttf-firacode-nerd noto-fonts qt5-wayland qt6-wayland\
    noto-fonts-emoji ttf-nerd-fonts-symbols-common otf-firamono-nerd \
    brightnessctl pipewire noise-suppression-for-voice lib32-pipewire wireplumber \
    pipewire-audio pipewire-pulse pipewire-alsa pipewire-jack ladspa motivewave \
    lib32-pipewire-jack xdg-user-dirs xdg-desktop-portal-hyprland sweet-gtk-theme --needed
fi

#  Copy .config files
read -n1 -rep $'Would you like to copy .config files? (Y/n) ' CFG
if [[ $CFG != "N" && $CFG != "n" ]]; then
    echo -e "Copying .config files...\n"
    cp -R .config/* ~/.config/
    # set as executable
    chmod +x ~/.config/waybar/scripts/*
    chmod +x ~/.config/hypr/xdg-portal-hyprland
fi

#   Install NVChad
read -n1 -rep $'Would you like to install NVChad? (Y/n) ' NVCHAD
if [[ $NVCHAD != "N" && $NVCHAD != "n" ]]; then
    echo -e "Installing NVChad...\n"
    git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1
fi

# set zsh as default bash
chsh -s /bin/zsh

#   Copy .zshrc and .zsh_plugins.txt
read -n1 -rep $'Would you like to copy .zshrc and .zsh_plugins.txt? (Y/n) ' ZSH
if [[ $ZSH != "N" && $ZSH != "n" ]]; then
    echo -e "Copying .zshrc and .zsh_plugins.txt...\n"
    cp .zshrc ~/.zshrc
    cp .zsh_plugins.txt ~/.zsh_plugins.txt
    # Ensure the files are readable
    chmod 644 ~/.zshrc ~/.zsh_plugins.txt
fi

#   Script is done
echo -e "Script had completed. Remember to set wifi service up. https://wiki.archlinux.org/title/Lenovo_ThinkPad_T14s_(AMD)_Gen_3 \n"
echo -e "You can start Hyprland by typing Hyprland (note the capital H).\n"
read -n1 -rep $'Would you like to reboot? (Y/n) ' HYP
if [[ $HYP != "N" && $HYP != "n" ]]; then
    reboot
else
    exit
fi
