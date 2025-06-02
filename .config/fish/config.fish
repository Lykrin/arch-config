function fish_greeting
  fastfetch -c ~/.config/fastfetch/minimal.jsonc
end

if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Set default editors
set -gx EDITOR nvim
set -gx VISUAL nvim

# Start Hyprland session via uwsm automatically when logging into TTY1
if status is-login; and status is-interactive; and test (tty) = "/dev/tty1"
    if uwsm check may-start
        exec systemd-cat -t uwsm_start uwsm start hyprland.desktop
    end
end

function lncrawl-venv
    # Store the current directory
    set -l current_dir (pwd)
    
    # Navigate to the project directory
    cd ~/lightnovel-crawler
    
    # Activate the virtual environment using the Fish-specific script
    source venv/bin/activate.fish
    
    # Run lncrawl with any arguments passed to the function
    lncrawl $argv
    
    # Deactivate the virtual environment
    # For Fish, we just run the deactivate function directly
    deactivate
    
    # Return to the original directory
    cd $current_dir
end

