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
        yay -S --noconfirm --needed --overwrite "/usr/lib/libjack*" -i \
            pipewire{,-pulse,-alsa,-jack,-audio} lib32-pipewire{,-jack} wireplumber noise-suppression-for-voice \
            zsh zsh-antidote hyprland waybar hypridle hyprlock hyprpaper \
            xdg-desktop-portal-hyprland polkit-gnome networkmanager-dmenu-git \
            network-manager-applet ffmpeg{,thumbnailer} wf-recorder grimblast-git \
            neovim foot{,-terminfo} nemo{,-fileroller} gvfs{,-mtp} \
            fuzzel bolt-launcher pavucontrol cliphist wl-clipboard clapper wttrbar \
            viewnior btop brave-bin vesktop mkinitcpio-firmware fprintd cava \
            nwg-look-bin dunst pamixer brightnessctl motivewave sweet-gtk-theme \
            sweet-folders-icons-git xdg-user-dirs fastfetch ladspa LADSPA \
            ttf-firacode-nerd noto-fonts{,-emoji} ttf-nerd-fonts-symbols-common \
            otf-firamono-nerd qt{5,6}-wayland
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Package installation completed"
    } 2>&1 | tee -a "$INSTLOG"
fi

# Copy .config files
if prompt_user "Would you like to copy .config files?"; then
    print_message "$GREEN" "Copying .config files..."
    cp -R .config/* ~/.config/
    cp -R wallpapers ~/
    cp -R .icons ~/
    cp -R .zshenv ~/
    sudo cp -f loader.conf /boot/loader/
    sudo cp -f mkinitcpio.conf /etc/
    sudo cp -f vconsole.conf /etc/
    chmod +x ~/.config/waybar/scripts/* ~/.config/hypr/xdg-portal-hyprland
fi

# Append Silent Boot Files
if prompt_user "Would you like to set up silent boot?"; then
    print_message "$GREEN" "Setting up silent boot..."
    sudo find /boot/loader/entries/ -name '*linux-zen.conf' -exec sed -i '/^options/ s/$/ quiet loglevel=2 systemd.show_status=auto rd.udev.log_level=2/' {} +
fi

# Install Kickstart
if prompt_user "Would you like to install Kickstart?"; then
    print_message "$GREEN" "Installing Kickstart..."
    git clone https://github.com/lykrin/kickstart.nvim.git "${XDG_CONFIG_HOME:-$HOME/.config}"/nvim
fi

# Implement udev rule for mic mute LED
if prompt_user "Would you like to implement the udev rule for the mic mute LED?"; then
    print_message "$GREEN" "Implementing udev rule for mic mute LED..."
    echo 'ACTION=="add", SUBSYSTEM=="leds", KERNEL=="platform::micmute" ATTR{trigger}="audio-micmute"' | sudo tee /etc/udev/rules.d/micmute-led.rules > /dev/null
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    print_message "$GREEN" "udev rule implemented and triggered."
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
