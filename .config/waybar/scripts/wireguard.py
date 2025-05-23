#!/usr/bin/env python3

import json
import subprocess
import sys
import os
import re # Import regex module

# --- Configuration ---
WG_CONF_DIR = "/etc/wireguard/"
WG0_INTERFACE_NAME = "wg0" # Define the specific interface for left-click

# Icons (Using Nerd Font characters)
ICON_CONNECTED = "" # Lock icon (nf-fa-lock)
ICON_DISCONNECTED = "" # Unlock alt icon (nf-fa-unlock_alt)
FUZZEL_CMD = "fuzzel --dmenu" # Adjust if fuzzel is not in PATH or needs args
# --- End Configuration ---

def run_command(command, input_data=None):
    """Runs a shell command and returns its output, errors, and return code."""
    try:
        process = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            input=input_data,
            check=False
        )
        # print(f"CMD: {command}\nSTDOUT: {process.stdout.strip()}\nSTDERR: {process.stderr.strip()}\nCODE: {process.returncode}", file=sys.stderr) # Uncomment for deep debug
        return process.stdout.strip(), process.stderr.strip(), process.returncode
    except Exception as e:
        print(f"Exception running command '{command}': {e}", file=sys.stderr)
        return None, str(e), 1

# --- STATUS CHECK FUNCTIONS (Unchanged) ---

def get_wg_status():
    """Checks if any WireGuard interface is UP using 'ip link' and checking <...,UP,...> flag."""
    stdout, stderr, returncode = run_command("ip link show type wireguard")
    if returncode == 0 and stdout:
        pattern = re.compile(r"<.*,UP.*>", re.MULTILINE)
        if pattern.search(stdout):
             return True
    return False

def get_active_interfaces():
    """Gets a list of currently active (UP) WireGuard interface names using 'ip link'."""
    active_interfaces = []
    stdout, stderr, returncode = run_command("ip link show type wireguard")
    if returncode == 0 and stdout:
        pattern = re.compile(r"^\d+:\s+([^:]+):\s+<.*,UP.*>.*$", re.MULTILINE)
        matches = pattern.findall(stdout)
        active_interfaces = matches
    return active_interfaces

# --- END STATUS CHECK FUNCTIONS ---


def list_wg_configs():
    """Lists available WireGuard configurations (without .conf suffix)."""
    try:
        if not os.path.isdir(WG_CONF_DIR):
            return []
        if not os.access(WG_CONF_DIR, os.R_OK | os.X_OK):
             return []
        files = [f for f in os.listdir(WG_CONF_DIR) if f.endswith(".conf")]
        return [f[:-5] for f in files]
    except Exception as e:
        print(f"Error listing configs in '{WG_CONF_DIR}': {e}", file=sys.stderr)
        return []

def select_with_fuzzel(options, prompt="Select WireGuard Config"):
    """Uses fuzzel to select an option from a list."""
    if not options:
        print("No options provided to fuzzel.", file=sys.stderr)
        return None

    options_str = "\n".join(options)
    fuzzel_full_cmd = f"{FUZZEL_CMD} -p '{prompt}: '"
    stdout, stderr, returncode = run_command(fuzzel_full_cmd, input_data=options_str)

    if returncode == 0 and stdout:
        return stdout
    elif returncode == 1: # User cancelled (e.g., Esc)
         return None
    else:
        if returncode != 1: # Avoid error message on user cancel
            print(f"Fuzzel error (code {returncode}): {stderr}", file=sys.stderr)
            run_command(f"notify-send 'WireGuard Script Error' 'Fuzzel failed: {stderr}' -u critical")
        return None

# --- FUZZEL-BASED TOGGLE FUNCTION (for Right-Click) ---
def toggle_connection_menu():
    """Handles connecting or disconnecting via fuzzel menu."""
    active_interfaces = get_active_interfaces()

    if active_interfaces:
        interface_to_disconnect = select_with_fuzzel(active_interfaces, "Disconnect WireGuard")
        if interface_to_disconnect:
            stdout, stderr, retcode = run_command(f"sudo wg-quick down {interface_to_disconnect}")
            if retcode != 0:
                run_command(f"notify-send 'WireGuard Error' 'Failed to disconnect {interface_to_disconnect}: {stderr}' -u critical")
                print(f"Error disconnecting {interface_to_disconnect}: {stderr}", file=sys.stderr)
            else:
                 run_command(f"notify-send 'WireGuard' 'Disconnected {interface_to_disconnect}' -u normal")
    else:
        available_configs = list_wg_configs()
        interface_to_connect = select_with_fuzzel(available_configs, "Connect WireGuard")
        if interface_to_connect:
            stdout, stderr, retcode = run_command(f"sudo wg-quick up {interface_to_connect}")
            if retcode != 0:
                run_command(f"notify-send 'WireGuard Error' 'Failed to connect {interface_to_connect}: {stderr}' -u critical")
                print(f"Error connecting {interface_to_connect}: {stderr}", file=sys.stderr)
            else:
                run_command(f"notify-send 'WireGuard' 'Connected {interface_to_connect}' -u normal")

# --- NEW DIRECT TOGGLE FUNCTION (for Left-Click) ---
def toggle_wg0_direct():
    """Directly toggles the specific WG0_INTERFACE_NAME up or down."""
    interface_name = WG0_INTERFACE_NAME
    active_interfaces = get_active_interfaces()
    is_wg0_active = interface_name in active_interfaces

    # Check if config file exists before trying to bring it up
    config_file = os.path.join(WG_CONF_DIR, f"{interface_name}.conf")
    if not is_wg0_active and not os.path.exists(config_file):
        err_msg = f"Config file not found: {config_file}"
        print(err_msg, file=sys.stderr)
        run_command(f"notify-send 'WireGuard Error' '{err_msg}' -u critical")
        return # Exit if config doesn't exist

    if is_wg0_active:
        # Currently active, bring it down
        print(f"Attempting to disconnect {interface_name}...", file=sys.stderr)
        stdout, stderr, retcode = run_command(f"sudo wg-quick down {interface_name}")
        if retcode != 0:
            run_command(f"notify-send 'WireGuard Error' 'Failed to disconnect {interface_name}: {stderr}' -u critical")
            print(f"Error disconnecting {interface_name}: {stderr}", file=sys.stderr)
        else:
             run_command(f"notify-send 'WireGuard' 'Disconnected {interface_name}' -u normal")
             print(f"Disconnected {interface_name}", file=sys.stderr)
    else:
        # Currently inactive, bring it up
        print(f"Attempting to connect {interface_name}...", file=sys.stderr)
        stdout, stderr, retcode = run_command(f"sudo wg-quick up {interface_name}")
        if retcode != 0:
            run_command(f"notify-send 'WireGuard Error' 'Failed to connect {interface_name}: {stderr}' -u critical")
            print(f"Error connecting {interface_name}: {stderr}", file=sys.stderr)
        else:
            run_command(f"notify-send 'WireGuard' 'Connected {interface_name}' -u normal")
            print(f"Connected {interface_name}", file=sys.stderr)

# --- WAYBAR OUTPUT FUNCTION (Optional Tooltip Change) ---
def print_waybar_output():
    """Prints the JSON output for Waybar."""
    status = {}
    try:
        is_connected = get_wg_status()
        active_interfaces = get_active_interfaces() if is_connected else []

        if is_connected:
            status['text'] = ICON_CONNECTED
            status['class'] = "connected"
            active_list = f"({', '.join(active_interfaces)})" if active_interfaces else ""
            # Updated tooltip to reflect click actions
            status['tooltip'] = f"WireGuard Connected {active_list}\nL-Click: Toggle {WG0_INTERFACE_NAME} / R-Click: Menu"
        else:
            status['text'] = ICON_DISCONNECTED
            status['class'] = "disconnected"
            # Updated tooltip to reflect click actions
            status['tooltip'] = f"WireGuard Disconnected\nL-Click: Connect {WG0_INTERFACE_NAME} / R-Click: Menu"

    except Exception as e:
        status['text'] = "WG ERR"
        status['tooltip'] = f"WireGuard script error: {e}"
        status['class'] = "error"
        print(f"Error in print_waybar_output: {e}", file=sys.stderr)

    print(json.dumps(status))
    sys.stdout.flush()


# --- MAIN EXECUTION BLOCK (Modified) ---
if __name__ == "__main__":
    if len(sys.argv) > 1:
        if sys.argv[1] == "--toggle": # Right-click: Fuzzel menu
            toggle_connection_menu()
        elif sys.argv[1] == "--toggle-wg0": # Left-click: Direct wg0 toggle
            toggle_wg0_direct()
        # else: Optional: handle unknown arguments?
        #    print(f"Unknown argument: {sys.argv[1]}", file=sys.stderr)
    else:
        # Default behavior: print Waybar status JSON
        print_waybar_output()
