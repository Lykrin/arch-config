#!/bin/bash
set -euo pipefail

RED='\u001B[0;31m'
GREEN='\u001B[0;32m'
YELLOW='\u001B[0;33m'
BLUE='\u001B[0;36m'
NC='\u001B[0m'
INSTLOG="install.log"

print_message() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

prompt_user() {
    local prompt=$1
    echo -en "${YELLOW}${prompt}${NC} (Y/n) "
    read -r response
    if [[ "$response" =~ ^[Nn]$ ]]; then
        return 1
    fi
    return 0
}

prompt_choice() {
    local prompt=$1
    shift
    local options=("$@")
    
    echo -e "${YELLOW}${prompt}${NC}"
    for i in "${!options[@]}"; do
        echo "  $((i + 1))) ${options[$i]}"
    done
    
    while true; do
        echo -en "${YELLOW}Enter choice [1-${#options[@]}]: ${NC}"
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            return $((choice - 1))
        fi
        print_message "$RED" "Invalid choice. Please try again."
    done
}

detect_gpu() {
    local gpu_info=$(lspci | grep -E "VGA|3D|Display")
    local detected=""
    
    if echo "$gpu_info" | grep -iq "nvidia"; then
        detected="${detected}NVIDIA "
    fi
    if echo "$gpu_info" | grep -iq "amd|radeon"; then
        detected="${detected}AMD "
    fi
    if echo "$gpu_info" | grep -iq "intel"; then
        detected="${detected}Intel "
    fi
    
    echo "${detected}"
}

update_yay() {
    yay -Syu --noconfirm "${@:-}" 2>&1 | tee -a "$INSTLOG"
}

install_packages() {
    yay -S --noconfirm --needed "$@" 2>&1 | tee -a "$INSTLOG"
}

extend_sudo_timeout() {
    print_message "$YELLOW" "Extending sudo session timeout..."
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}

cleanup() {
    jobs -p | xargs -r kill 2>/dev/null
}

configure_nvidia_hyprland() {
    local hypr_conf="$HOME/.config/hypr/hyprland.conf"
    
    if [ -f "$hypr_conf" ]; then
        if ! grep -q "LIBVA_DRIVER_NAME,nvidia" "$hypr_conf"; then
            print_message "$YELLOW" "Adding Nvidia environment variables to hyprland.conf..."
            cat >> "$hypr_conf" <<EOF

# Nvidia-specific environment variables
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct

cursor {
    no_hardware_cursors = true
}
EOF
            print_message "$GREEN" "Nvidia configuration added to hyprland.conf"
        fi
    fi
}

configure_nvidia_boot() {
    print_message "$YELLOW" "Configuring boot parameters for Nvidia..."
    
    local boot_entries=$(find /boot/loader/entries/ -name '*.conf' 2>/dev/null)
    
    if [ -n "$boot_entries" ]; then
        for entry in $boot_entries; do
            if ! grep -q "nvidia_drm.modeset=1" "$entry"; then
                sudo sed -i.bak '/^options/ s/$/ nvidia_drm.modeset=1 nvidia_drm.fbdev=1/' "$entry"
                print_message "$GREEN" "Updated boot parameters in $(basename "$entry")"
            fi
        done
    fi
}

configure_nvidia_mkinitcpio() {
    local mkinitcpio_conf="/etc/mkinitcpio.conf"
    
    if [ -f "$mkinitcpio_conf" ]; then
        print_message "$YELLOW" "Adding Nvidia modules to mkinitcpio.conf..."
        sudo cp "$mkinitcpio_conf" "${mkinitcpio_conf}.bak"
        
        if ! grep -q "nvidia nvidia_modeset nvidia_uvm nvidia_drm" "$mkinitcpio_conf"; then
            sudo sed -i '/^MODULES=/ s/)/ nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$mkinitcpio_conf"
            print_message "$GREEN" "Nvidia modules added to mkinitcpio.conf"
            
            print_message "$YELLOW" "Regenerating initramfs..."
            sudo mkinitcpio -P
        fi
    fi
}

trap cleanup EXIT INT TERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

if pacman -Qq base-devel &>/dev/null; then
    print_message "$GREEN" "Base Devel located, moving on."
else
    print_message "$RED" "Base Devel is required for this script. Exiting..."
    exit 1
fi

extend_sudo_timeout

if command -v yay &>/dev/null; then
    print_message "$GREEN" "Yay located, updating system."
    update_yay
else
    print_message "$RED" "Yay not found."
    if prompt_user "Would you like to install yay?"; then
        [ -d "yay" ] && rm -rf yay
        git clone https://aur.archlinux.org/yay.git 2>> "$INSTLOG"
        (cd yay && makepkg -si --noconfirm 2>> "$INSTLOG")
        rm -rf yay
        update_yay --sudoloop
    else
        print_message "$RED" "Yay is required for this script. Exiting..."
        exit 1
    fi
fi

detected_gpus=$(detect_gpu)
print_message "$BLUE" "Detected GPU(s): ${detected_gpus:-Unknown}"

if prompt_user "Would you like to select your GPU type for driver installation?"; then
    gpu_options=("NVIDIA (Proprietary)" "AMD" "Intel" "Hybrid (NVIDIA + AMD/Intel)" "Skip GPU drivers")
    prompt_choice "Select your GPU configuration:" "${gpu_options[@]}"
    gpu_choice=$?
    
    case $gpu_choice in
        0)
            GPU_TYPE="nvidia"
            print_message "$GREEN" "Selected: NVIDIA"
            ;;
        1)
            GPU_TYPE="amd"
            print_message "$GREEN" "Selected: AMD"
            ;;
        2)
            GPU_TYPE="intel"
            print_message "$GREEN" "Selected: Intel"
            ;;
        3)
            GPU_TYPE="hybrid"
            print_message "$GREEN" "Selected: Hybrid (NVIDIA + AMD/Intel)"
            ;;
        4)
            GPU_TYPE="skip"
            print_message "$YELLOW" "Skipping GPU driver installation"
            ;;
    esac
else
    GPU_TYPE="skip"
fi

if prompt_user "Would you like to install the packages?"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting package installation" | tee -a "$INSTLOG"

    base_deps=(cmake ninja meson wayland-protocols libxcb xcb-proto xcb-util xcb-util-keysyms
               libxfixes libx11 libxcomposite xorg-xinput libxrender pixman libdrm libxkbcommon
               xcb-util-wm xorg-xwayland glslang qt6-wayland pugixml)
    install_packages "${base_deps[@]}"

    audio_deps=(pipewire pipewire-pulse pipewire-alsa pipewire-jack pipewire-audio
                lib32-pipewire lib32-pipewire-jack wireplumber noise-suppression-for-voice)
    install_packages "${audio_deps[@]}"

    case "$GPU_TYPE" in
        nvidia)
            print_message "$BLUE" "Installing NVIDIA drivers and packages..."
            
            if uname -r | grep -q "zen"; then
                nvidia_packages=(linux-zen-headers nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings egl-wayland libva-nvidia-driver)
            else
                nvidia_packages=(linux-headers nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings egl-wayland libva-nvidia-driver)
            fi
            install_packages "${nvidia_packages[@]}"
            
            mesa_packages=(mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader)
            install_packages "${mesa_packages[@]}"
            ;;
            
        amd)
            print_message "$BLUE" "Installing AMD drivers and packages..."
            amd_packages=(mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon 
                         libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau)
            install_packages "${amd_packages[@]}"
            ;;
            
        intel)
            print_message "$BLUE" "Installing Intel drivers and packages..."
            intel_packages=(mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver 
                           libva-intel-driver lib32-libva-intel-driver)
            install_packages "${intel_packages[@]}"
            ;;
            
        hybrid)
            print_message "$BLUE" "Installing hybrid GPU drivers (NVIDIA + AMD/Intel)..."
            
            if uname -r | grep -q "zen"; then
                nvidia_packages=(linux-zen-headers nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings 
                               nvidia-prime egl-wayland libva-nvidia-driver)
            else
                nvidia_packages=(linux-headers nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings 
                               nvidia-prime egl-wayland libva-nvidia-driver)
            fi
            install_packages "${nvidia_packages[@]}"
            
            hybrid_packages=(mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-intel 
                           lib32-vulkan-intel libva-mesa-driver lib32-libva-mesa-driver 
                           mesa-vdpau lib32-mesa-vdpau)
            install_packages "${hybrid_packages[@]}"
            ;;
            
        skip)
            print_message "$YELLOW" "Skipping GPU driver installation as requested"
            ;;
    esac

    hypr_packages=(hyprutils hyprlang hyprwayland-scanner hyprland-protocols
                  hyprgraphics hyprland-qt-support hyprland-qtutils hyprcursor
                  aquamarine hyprland)
    install_packages "${hypr_packages[@]}"

    hypr_utils=(hypridle hyprlock hyprpaper hyprpolkitagent xdg-desktop-portal-hyprland)
    install_packages "${hypr_utils[@]}"

    other_packages=(fish waybar iwd ffmpeg ffmpegthumbnailer wf-recorder ydotool grimblast-git 
                    uwsm neovim foot foot-terminfo nemo nemo-fileroller gvfs gvfs-mtp fuzzel 
                    pavucontrol cliphist wl-clipboard wttrbar mpv btop vivaldi vesktop fprintd 
                    cava dunst pamixer brightnessctl catppuccin-gtk-theme-mocha sweet-folders-icons-git 
                    xdg-user-dirs fastfetch ladspa noto-fonts-cjk ttf-firacode-nerd noto-fonts 
                    noto-fonts-emoji steam ttf-nerd-fonts-symbols-common otf-firamono-nerd qt5-wayland 
                    qt6-wayland mkinitcpio-firmware ib-tws nwg-look bolt-launcher bibata-cursor-theme-bin 
                    gnome-themes-extra qt5ct qt6ct ripgrep xdg-desktop-portal xdg-desktop-portal-gtk 
                    qbittorrent-enhanced xsettingsd breeze-icons jre11-openjdk libva lib32-vulkan-icd-loader 
                    libvdpau-va-gl)
    install_packages "${other_packages[@]}"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Package installation completed" | tee -a "$INSTLOG"
    
    for pkg in hyprland fish foot; do
        if ! pacman -Qq "$pkg" &>/dev/null; then
            print_message "$RED" "Critical package $pkg failed to install!"
        fi
    done
fi

if [[ "$GPU_TYPE" == "nvidia" || "$GPU_TYPE" == "hybrid" ]]; then
    if prompt_user "Would you like to configure Nvidia settings for Hyprland?"; then
        configure_nvidia_mkinitcpio
        configure_nvidia_boot
        print_message "$YELLOW" "Note: Hyprland Nvidia config will be added after copying config files"
    fi
fi

if prompt_user "Would you like to set Fish as your default shell?"; then
    print_message "$GREEN" "Setting Fish as default shell..."
    if ! grep -q "/usr/bin/fish" /etc/shells; then
        echo "/usr/bin/fish" | sudo tee -a /etc/shells
    fi
    sudo chsh -s /usr/bin/fish "$USER"
    print_message "$GREEN" "Fish shell set as default. Changes take effect after logout/login."
fi

if prompt_user "Would you like to copy configuration files?"; then
    if [ ! -d ".config" ] && [ ! -d "wallpapers" ] && [ ! -d ".icons" ]; then
        print_message "$RED" "No configuration directories found in current directory"
    else
        print_message "$GREEN" "Copying configuration files..."
        mkdir -p ~/.config ~/.icons

        if [ -d ".config" ]; then
            cp -R .config/* ~/.config/
            print_message "$GREEN" "Copied .config files"
        fi

        if [ -d "wallpapers" ]; then
            cp -R wallpapers ~/
            print_message "$GREEN" "Copied wallpapers"
        fi

        if [ -d ".icons" ]; then
            cp -R .icons/* ~/.icons/
            print_message "$GREEN" "Copied .icons files"
        fi

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
            print_message "$GREEN" "Copied locale.gen"
        fi

        [ -d ~/.config/waybar/scripts ] && chmod +x ~/.config/waybar/scripts/*
        [ -f ~/.config/hypr/xdg-portal-hyprland ] && chmod +x ~/.config/hypr/xdg-portal-hyprland

        if [[ "$GPU_TYPE" == "nvidia" || "$GPU_TYPE" == "hybrid" ]]; then
            configure_nvidia_hyprland
        fi

        print_message "$GREEN" "Configuration files copied successfully"
    fi
fi

if prompt_user "Would you like to set up silent boot for zen kernel?"; then
    print_message "$GREEN" "Setting up silent boot for zen kernel..."
    zen_conf=$(find /boot/loader/entries/ -name '*linux-zen.conf' -print -quit)
    if [ -n "$zen_conf" ]; then
        sudo sed -i.bak '/^options/ s/$/ quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3/' "$zen_conf"
        print_message "$GREEN" "Silent boot configured for zen kernel"
    else
        print_message "$YELLOW" "No zen kernel entry found"
    fi
fi

if prompt_user "Would you like to create the udev rule for ydotool (uinput)?"; then
    print_message "$GREEN" "Creating udev rule for ydotool..."
    sudo install -D -m 0644 /dev/stdin /etc/udev/rules.d/70-ydotool-uinput.rules <<'EOF'
KERNEL=="uinput", GROUP="input", MODE="0660"
EOF
    sudo udevadm control --reload
    sudo udevadm trigger -s input
    print_message "$GREEN" "udev rule installed and applied."
fi

if prompt_user "Would you like to install Kickstart Neovim config?"; then
    print_message "$GREEN" "Installing Kickstart Neovim config..."
    if [ -d ~/.config/nvim ]; then
        if [ -d ~/.config/nvim/.git ]; then
            rm -rf ~/.config/nvim
        else
            mv ~/.config/nvim ~/.config/nvim.backup.$(date +%Y%m%d_%H%M%S)
        fi
    fi
    git clone https://github.com/lykrin/kickstart.nvim.git ~/.config/nvim
fi

if prompt_user "Would you like to regenerate locale?"; then
    print_message "$GREEN" "Regenerating locale..."
    sudo locale-gen
    print_message "$GREEN" "Locale generated"
fi

if prompt_user "Would you like to add user to input group?"; then
    if ! groups "$USER" | grep -q '\binput\b'; then
        sudo gpasswd -a "$USER" input
        print_message "$GREEN" "User added to input group"
    else
        print_message "$YELLOW" "User already in input group"
    fi
fi

if command -v gsettings &>/dev/null && [ -n "${DISPLAY:-${WAYLAND_DISPLAY:-}}" ]; then
    gsettings set org.gnome.desktop.interface gtk-theme "catppuccin-mocha-teal-standard+default"
    gsettings set org.gnome.desktop.wm.preferences theme "catppuccin-mocha-teal-standard+default"
    gsettings set org.gnome.desktop.interface icon-theme "Breeze-Dark"
    gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
fi

print_message "$GREEN" "Script completed successfully!"
print_message "$YELLOW" "Important notes:"
print_message "$YELLOW" "- Fish shell is now your default shell (effective after logout/login)"
print_message "$YELLOW" "- UWSM configuration is included in your .config files"
print_message "$YELLOW" "- Hyprland will auto-start on TTY1 login with UWSM"

if [[ "$GPU_TYPE" == "nvidia" || "$GPU_TYPE" == "hybrid" ]]; then
    print_message "$YELLOW" "- Nvidia drivers installed with proper kernel parameters"
    print_message "$YELLOW" "- Hyprland Nvidia environment variables configured"
    print_message "$YELLOW" "- For hybrid setups, use 'prime-run' to run apps on Nvidia GPU"
fi

if [[ "$GPU_TYPE" == "amd" ]]; then
    print_message "$YELLOW" "- AMD drivers installed with Vulkan and VAAPI support"
fi

if prompt_user "Would you like to reboot now to apply all changes?"; then
    sudo reboot
fi