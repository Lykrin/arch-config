#!/bin/bash

# Anti-AFK toggle switch script - ydotool only with startup test
# Uses ydotool for maximum game compatibility

SCRIPT_DIR="$HOME/.config/waybar/scripts"
PID_FILE="$SCRIPT_DIR/.anti-afk.pid"
STATUS_FILE="$SCRIPT_DIR/.anti-afk.status"

# Ensure directories exist
mkdir -p "$SCRIPT_DIR"

# Set manual socket path for ydotool
export YDOTOOL_SOCKET=/run/user/$(id -u)/.ydotool_socket

# Function to generate random delays between 2-4 seconds
generate_random_delay() {
    awk "BEGIN {srand(); printf \"%.3f\", 2 + rand() * 2}"
}

# Function to send Enter key via ydotool
send_enter() {
    # Key code 28 is Enter, format is keycode:1 (press) keycode:0 (release)
    YDOTOOL_SOCKET=$YDOTOOL_SOCKET ydotool key 28:1 28:0
}

# Function to perform single anti-AFK sequence
perform_anti_afk_sequence() {
    echo "pressing" > "$STATUS_FILE"
    
    # Send 4 Enter presses with random delays between each
    send_enter
    sleep "$(generate_random_delay)"
    
    send_enter
    sleep "$(generate_random_delay)"
    
    send_enter
    sleep "$(generate_random_delay)"
    
    send_enter
    
    echo "active" > "$STATUS_FILE"
}

# Background daemon function
anti_afk_daemon() {
    echo "active" > "$STATUS_FILE"
    
    # Perform immediate startup test sequence
    perform_anti_afk_sequence
    
    while [[ -f "$PID_FILE" ]]; do
        # Wait for next cycle (18-20 minutes) with periodic checks
        local wait_time=$(shuf -i 1080-1200 -n 1)  # 18-20 minutes in seconds
        local elapsed=0
        
        while [[ $elapsed -lt $wait_time && -f "$PID_FILE" ]]; do
            sleep 10  # Check every 10 seconds if we should stop
            elapsed=$((elapsed + 10))
        done
        
        # Check if we should still be running
        if [[ -f "$PID_FILE" ]]; then
            perform_anti_afk_sequence
        fi
    done
    
    echo "inactive" > "$STATUS_FILE"
}

# Function to start the anti-AFK daemon
start_anti_afk() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        return 1  # Already running
    fi
    
    # Clean up any stale files
    rm -f "$PID_FILE" "$STATUS_FILE"
    
    # Perform immediate test sequence before starting daemon
    echo "Testing key presses..."
    perform_anti_afk_sequence
    echo "Test completed. Starting daemon..."
    
    # Start daemon in background using nohup for better process management
    nohup bash -c "
        $(declare -f anti_afk_daemon)
        $(declare -f perform_anti_afk_sequence) 
        $(declare -f generate_random_delay)
        $(declare -f send_enter)
        SCRIPT_DIR='$SCRIPT_DIR'
        PID_FILE='$PID_FILE'
        STATUS_FILE='$STATUS_FILE'
        export YDOTOOL_SOCKET=$YDOTOOL_SOCKET
        anti_afk_daemon
    " > /dev/null 2>&1 &
    
    local daemon_pid=$!
    
    # Save PID
    echo "$daemon_pid" > "$PID_FILE"
    
    # Wait a moment to ensure it started
    sleep 1
    
    if kill -0 "$daemon_pid" 2>/dev/null; then
        echo "active" > "$STATUS_FILE"
        return 0
    else
        rm -f "$PID_FILE"
        echo "inactive" > "$STATUS_FILE"
        return 1
    fi
}

# Function to stop the anti-AFK daemon
stop_anti_afk() {
    if [[ ! -f "$PID_FILE" ]]; then
        return 1  # Not running
    fi
    
    local pid=$(cat "$PID_FILE")
    
    # Kill the daemon process and its children
    if kill "$pid" 2>/dev/null; then
        # Wait for graceful shutdown
        sleep 1
        # Force kill if still running
        kill -9 "$pid" 2>/dev/null
        rm -f "$PID_FILE"
        echo "inactive" > "$STATUS_FILE"
        return 0
    else
        # Process might already be dead, clean up anyway
        rm -f "$PID_FILE"
        echo "inactive" > "$STATUS_FILE"
        return 1
    fi
}

# Function to toggle anti-AFK state
toggle_anti_afk() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        stop_anti_afk
    else
        start_anti_afk
    fi
}

# Function to check if process is actually running
is_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            # Process died, clean up
            rm -f "$PID_FILE"
            echo "inactive" > "$STATUS_FILE"
            return 1
        fi
    fi
    return 1
}

# Function to get status for Waybar display
get_status() {
    if is_running; then
        local status=$(cat "$STATUS_FILE" 2>/dev/null || echo "active")
        case "$status" in
            "pressing")
                echo '{"text": "🔄", "class": "pressing", "tooltip": "Anti-AFK: Pressing keys..."}'
                ;;
            "active")
                echo '{"text": "🟢", "class": "active", "tooltip": "Anti-AFK: ON (Click to turn OFF)"}'
                ;;
        esac
    else
        echo '{"text": "🔴", "class": "inactive", "tooltip": "Anti-AFK: OFF (Click to turn ON)"}'
    fi
}

# Initialize status file if it doesn't exist
if [[ ! -f "$STATUS_FILE" ]]; then
    echo "inactive" > "$STATUS_FILE"
fi

# Main logic
case "${1:-status}" in
    "toggle")
        toggle_anti_afk
        ;;
    "start")
        start_anti_afk
        ;;
    "stop")
        stop_anti_afk
        ;;
    "status")
        get_status
        ;;
    "debug")
        echo "PID file exists: $(test -f "$PID_FILE" && echo "yes" || echo "no")"
        if [[ -f "$PID_FILE" ]]; then
            echo "PID: $(cat "$PID_FILE")"
            echo "Process running: $(kill -0 "$(cat "$PID_FILE")" 2>/dev/null && echo "yes" || echo "no")"
        fi
        echo "Status file: $(cat "$STATUS_FILE" 2>/dev/null || echo "missing")"
        ;;
    "test")
        echo "Testing key presses..."
        perform_anti_afk_sequence
        echo "Test completed."
        ;;
esac
