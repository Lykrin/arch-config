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
        yay -Syu --sudoloop --noconfirm
    else
        print_message "$RED" "Yay is required for this script, now exiting"
        exit 1
    fi
fi

# Install packages
   if prompt_user "Would you like to install the packages?"; then
   {
       echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting package installation"
       
# Base dependencies first
yay -S --noconfirm --needed cmake ninja meson wayland-protocols \
    libxcb xcb-proto xcb-util xcb-util-keysyms libxfixes libx11 \
    libxcomposite xorg-xinput libxrender pixman wayland-protocols \
    libdrm libxkbcommon xcb-util-wm xorg-xwayland glslang \
    qt6-wayland pugixml

# Audio stack
yay -S --noconfirm --needed pipewire pipewire-pulse pipewire-alsa \
    pipewire-jack pipewire-audio lib32-pipewire lib32-pipewire-jack \
    wireplumber noise-suppression-for-voice

# Install git versions with force flag
yay -S --noconfirm --needed --overwrite "*" \
    hyprutils-git \
    hyprlang-git \
    hyprwayland-scanner-git \
    hyprland-protocols-git \
    hyprgraphics-git \
    hyprland-qt-support-git \
    hyprland-qtutils-git \
    hyprcursor-git \
    aquamarine-git \
    hyprland-git

# Install additional utilities after core components
yay -S --noconfirm --needed --overwrite "*" \
    hypridle-git \
    hyprlock-git \
    hyprpaper-git \
    hyprpolkitagent-git \
    xdg-desktop-portal-hyprland-git

# Rest of the packages
yay -S --noconfirm --needed fish waybar networkmanager-dmenu \
    network-manager-applet ffmpeg ffmpegthumbnailer wf-recorder \
    grimblast-git uwsm neovim foot foot-terminfo nemo nemo-fileroller \
    gvfs gvfs-mtp fuzzel pavucontrol cliphist wl-clipboard clapper \
    wttrbar viewnior btop vivaldi vesktop fprintd cava dunst pamixer \
    brightnessctl sweet-gtk-theme sweet-folders-icons-git xdg-user-dirs \
    fastfetch ladspa ttf-firacode-nerd noto-fonts noto-fonts-emoji steam \
    ttf-nerd-fonts-symbols-common otf-firamono-nerd qt5-wayland qt6-wayland \
    motivewave mkinitcpio-firmware ib-tws nwg-look bolt-launcher bibata-cursor-theme-bin
       
       echo "[$(date '+%Y-%m-%d %H:%M:%S')] Package installation completed"
   } 2>&1 | grep -E "error|warning|critical|failed" | tee -a "$INSTLOG"
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
    sudo find /boot/loader/entries/ -name '*linux-zen.conf' -exec sed -i '/^options/ s/$/ amdgpu.dcdebugmask=0x10/' {} +
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
