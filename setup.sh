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

# Install packages
   if prompt_user "Would you like to install the packages?"; then
   {
       echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting package installation"
       
       # Install PipeWire and its components first
       yay -S --noconfirm --needed \
           pipewire{,-pulse,-alsa,-jack,-audio} lib32-pipewire{,-jack} \
           wireplumber noise-suppression-for-voice

yay -S --noconfirm --needed hyprland-git
       
       # Install the rest of the packages
       yay -S --noconfirm --needed \
           hypridle-git hyprlock-git hyprpaper-git hyprpolkitagent-git \
           xdg-desktop-portal-hyprland-git fish waybar-git networkmanager-dmenu-git \
           network-manager-applet ib-tws ffmpeg{,thumbnailer} wf-recorder grimblast-git \
           uwsm  neovim foot{,-terminfo} nemo{,-fileroller} gvfs{,-mtp} \
           fuzzel bolt-launcher pavucontrol cliphist wl-clipboard clapper wttrbar \
           viewnior btop vivaldi vesktop mkinitcpio-firmware fprintd cava \
           nwg-look-bin dunst pamixer brightnessctl motivewave sweet-gtk-theme \
           sweet-folders-icons-git xdg-user-dirs fastfetch ladspa LADSPA \
           ttf-firacode-nerd noto-fonts{,-emoji} ttf-nerd-fonts-symbols-common \
           otf-firamono-nerd qt5-wayland qt6-wayland
       
       echo "[$(date '+%Y-%m-%d %H:%M:%S')] Package installation completed"
   } 2>&1 | tee -a "$INSTLOG"
   fi

# Copy .config files
if prompt_user "Would you like to copy .config files?"; then
    print_message "$GREEN" "Copying .config files..."
    cp -R .config/* ~/.config/
    cp -R wallpapers ~/
    cp -R .icons ~/
    sudo cp -f loader.conf /boot/loader/
    sudo cp -f mkinitcpio.conf /etc/
    sudo cp -f vconsole.conf /etc/
    sudo cp -f motivewave /bin/
    chmod +x ~/.config/waybar/scripts/* ~/.config/hypr/xdg-portal-hyprland
fi

# Append Silent Boot Files
if prompt_user "Would you like to set up silent boot?"; then
    print_message "$GREEN" "Setting up silent boot..."
    sudo find /boot/loader/entries/ -name '*linux-zen.conf' -exec sed -i '/^options/ s/$/ quiet loglevel=2 systemd.show_status=auto rd.udev.log_level=2/' {} +
fi


# Fix the Flickering
if prompt_user "Would you like to fix the Artifacts?"; then
    print_message "$GREEN" "Setting up panel refresh..."
    sudo find /boot/loader/entries/ -name '*linux-zen.conf' -exec sed -i '/^options/ s/$/ amdgpu.dcdebugmask=0x10' {} +
fi

# Implement udev rule for mic mute LED
# to be done

# Set fish as default shell
#chsh -s /bin/fish

#Install Fisher 
#curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher

#Install Tidy
#fisher install IlanCosman/tide@v6

# Install Kickstart
if prompt_user "Would you like to install #Kickstart?"; then
    print_message "$GREEN" "Installing #Kickstart..."
    git clone https://github.com/lykrin/kickstart.nvim.git "${XDG_CONFIG_HOME:-$HOME/.config}"/nvim
fi

# Script completion
print_message "$GREEN" "Script has completed. Remember to set NM and quiet boot"
print_message "$GREEN" "You can start Hyprland by typing Hyprland (note the capital H)."

# Prompt for reboot
if prompt_user "Would you like to reboot?"; then
    reboot
fi
