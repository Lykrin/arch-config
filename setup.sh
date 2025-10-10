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

# Function to extend sudo timeout to avoid repeated password prompts
extend_sudo_timeout() {
    print_message "$YELLOW" "Extending sudo session timeout for this script..."
    sudo -v
    # Keep sudo alive in background
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}

# Ensure required dependencies are available
if pacman -Qq base-devel &>/dev/null; then
    print_message "$GREEN" "Base Devel located, moving on."
else
    print_message "$RED" "Base Devel is required for this script. Exiting..."
    exit 1
fi

# Extend sudo timeout early to avoid repeated prompts
extend_sudo_timeout

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
    install_packages "--sudoloop --removemake --cleanafter" "${base_deps[@]}"
    
    # Audio stack
    audio_deps=(pipewire pipewire-pulse pipewire-alsa pipewire-jack pipewire-audio
                lib32-pipewire lib32-pipewire-jack wireplumber noise-suppression-for-voice)
    install_packages "--sudoloop --removemake --cleanafter" "${audio_deps[@]}"
    
    # Git packages with overwrite option
    hypr_packages=(hyprutils hyprlang hyprwayland-scanner hyprland-protocols
                  hyprgraphics hyprland-qt-support hyprland-qtutils hyprcursor
                  aquamarine hyprland)
    install_packages "--sudoloop --removemake --cleanafter" "${hypr_packages[@]}"
    
    # Additional utilities with overwrite option
    hypr_utils=(hypridle hyprlock hyprpaper hyprpolkitagent
                      xdg-desktop-portal-hyprland)
    install_packages "--sudoloop --removemake --cleanafter" "${hypr_utils[@]}"
    
    # Rest of the packages - removed NetworkManager and added iwd for iwctl
    other_packages=(fish waybar iwd ffmpeg ffmpegthumbnailer
                    wf-recorder ydotool grimblast-git uwsm neovim foot foot-terminfo nemo nemo-fileroller
                    gvfs gvfs-mtp fuzzel pavucontrol cliphist wl-clipboard wttrbar mpv
                    btop vivaldi vesktop fprintd cava dunst pamixer brightnessctl catppuccin-gtk-theme-mocha
                    sweet-folders-icons-git xdg-user-dirs fastfetch ladspa noto-fonts-cjk ttf-firacode-nerd noto-fonts
                    noto-fonts-emoji steam ttf-nerd-fonts-symbols-common otf-firamono-nerd qt5-wayland
                    qt6-wayland mkinitcpio-firmware ib-tws nwg-look bolt-launcher bibata-cursor-theme-bin
                    gnome-themes-extra qt5ct qt6ct ripgrep xdg-desktop-portal xdg-desktop-portal-gtk
                    qbittorrent-enhanced xsettingsd breeze-icons jre11-openjdk libva lib32-vulkan-mesa-layers libvdpau-va-gl)
    install_packages "--sudoloop --removemake --cleanafter" "${other_packages[@]}"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Package installation completed" | tee -a "$INSTLOG"
fi

# Set Fish as default shell
if prompt_user "Would you like to set Fish as your default shell?"; then
    print_message "$GREEN" "Setting Fish as default shell..."
    
    # Check if fish is in /etc/shells
    if ! grep -q "/usr/bin/fish" /etc/shells; then
        echo "/usr/bin/fish" | sudo tee -a /etc/shells
    fi
    
    # Change default shell to fish
    sudo chsh -s /usr/bin/fish "$USER"
    print_message "$GREEN" "Fish shell set as default. Changes will take effect after logout/login."
fi

# Copy configuration files if requested
if prompt_user "Would you like to copy configuration files?"; then
    print_message "$GREEN" "Copying configuration files..."
    
    # Create necessary directories
    mkdir -p ~/.config ~/.icons
    
    # Copy .config directory contents (includes UWSM configuration)
    if [ -d ".config" ]; then
        cp -R .config/* ~/.config/
        print_message "$GREEN" "Copied .config files (including UWSM configuration)"
    fi
    
    # Copy wallpapers directory
    if [ -d "wallpapers" ]; then
        cp -R wallpapers ~/
        print_message "$GREEN" "Copied wallpapers"
    fi
    
    # Copy icons directory
    if [ -d ".icons" ]; then
        cp -R .icons/* ~/.icons/
        print_message "$GREEN" "Copied .icons files"
    fi
    
    # Copy system configuration files
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
        print_message "$GREEN" "Copied Locale file"
    fi
    
    # Set executable permissions for scripts
    if [ -d ~/.config/waybar/scripts ]; then
        chmod +x ~/.config/waybar/scripts/*
    fi
    
    if [ -f ~/.config/hypr/xdg-portal-hyprland ]; then
        chmod +x ~/.config/hypr/xdg-portal-hyprland
    fi
    
    print_message "$GREEN" "Configuration files copied successfully"
fi

# Setup silent boot for zen kernel
if prompt_user "Would you like to set up silent boot for zen kernel?"; then
    print_message "$GREEN" "Setting up silent boot for zen kernel..."
    sudo find /boot/loader/entries/ -name '*linux-zen.conf' \
      -exec sed -i '/^options/ s/$/ quiet loglevel=2 systemd.show_status=auto rd.udev.log_level=2/' {} +
    print_message "$GREEN" "Silent boot configured for zen kernel"
fi

# Create udev rule for ydotool (uinput)
if prompt_user "Would you like to create the udev rule for ydotool (uinput)?"; then
    print_message "$GREEN" "Creating /etc/udev/rules.d/70-ydotool-uinput.rules ..."
    sudo install -D -m 0644 /dev/stdin /etc/udev/rules.d/70-ydotool-uinput.rules <<'EOF'
KERNEL=="uinput", GROUP="input", MODE="0660"
EOF
    sudo udevadm control --reload
    sudo udevadm trigger -s input
    print_message "$GREEN" "udev rule installed and applied. Add user to 'input' group if needed."
fi

# Kickstart installation (optional)
if prompt_user "Would you like to install Kickstart Neovim config?"; then
    print_message "$GREEN" "Installing Kickstart Neovim config..."
    # Backup existing nvim config if it exists and it's not from the repo
    if [ -d ~/.config/nvim ] && [ ! -f ~/.config/nvim/.repo_config ]; then
        mv ~/.config/nvim ~/.config/nvim.backup.$(date +%Y%m%d_%H%M%S)
    fi
    git clone https://github.com/lykrin/kickstart.nvim.git ~/.config/nvim
fi

if prompt_user "Would you like to regenerate locale?"; then
    print_message "$GREEN" "Setting up locale..."
    sudo locale-gen
    print_message "$GREEN" "Locale Generated"
fi

if prompt_user "Would you like to add user to input group?"; then
    print_message "$GREEN" "Adding user..."
    sudo gpasswd -a "$USER" input
    print_message "$GREEN" "User now in input group"
fi

# GTK themes
gsettings set org.gnome.desktop.interface gtk-theme "catppuccin-mocha-teal-standard+default"
gsettings set org.gnome.desktop.wm.preferences theme "catppuccin-mocha-teal-standard+default"
gsettings set org.gnome.desktop.interface icon-theme "Breeze-Dark"
gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice"
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"


print_message "$GREEN" "Script has completed successfully!"
print_message "$YELLOW" "Important notes:"
print_message "$YELLOW" "- Fish shell is now your default shell (effective after logout/login)"
print_message "$YELLOW" "- UWSM configuration is already included in your .config files"
print_message "$YELLOW" "- Hyprland will auto-start on TTY1 login with your existing UWSM setup"
print_message "$YELLOW" "- Silent boot is configured for zen kernel"
print_message "$YELLOW" "- Locale regenerated and set up"

# Prompt for reboot
if prompt_user "Would you like to reboot now to apply all changes?"; then
    sudo reboot
fi
