#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import subprocess
import re
import argparse
import os
import sys
import time

# --- Configuration ---
FUZZEL_CMD = os.environ.get("FUZZEL_CMD", "fuzzel --dmenu")
FUZZEL_PASSWORD_CMD = os.environ.get("FUZZEL_PASSWORD_CMD", "fuzzel --dmenu --password")
NOTIFY_CMD = "notify-send"
DEFAULT_DEVICE = "wlan0" # Fallback Wi-Fi device
NOTIFY_TITLE = "WiFi Menu (iwctl)"

# --- Global State ---
DEVICE = None
SELECTED_SSID = None

# --- Icons ---
ICON_SCAN = "󰖩"
ICON_KNOWN = "󱚸"
ICON_DISCONNECT = "󰖪"
ICON_EXIT = "󰗼"
ICON_STATUS_CONNECTED = "󰖩"
ICON_STATUS_DISCONNECTED = "󰖪"
ICON_STATUS_CONNECTING = "󰖩 ..."

# --- Helper Functions ---

def run_command(command, expect_output=True, input_text=None, shell_mode=False):
    """Runs a shell command and returns its subprocess.CompletedProcess object."""
    try:
        process = subprocess.run(
            command,
            shell=shell_mode,
            capture_output=expect_output,
            text=True,
            input=input_text,
            check=False
        )
        if process.returncode != 0 and expect_output:
            is_fuzzel_cancel = False
            cmd_str_for_check = command[0] if isinstance(command, list) else command.split()[0]
            if "fuzzel" in cmd_str_for_check:
                 if process.returncode == 1 and not process.stdout.strip() and not process.stderr.strip():
                    is_fuzzel_cancel = True
            if not is_fuzzel_cancel:
                 cmd_str_display = ' '.join(command) if isinstance(command, list) else command
                 print(f"Error running command: {cmd_str_display}", file=sys.stderr)
                 if process.stderr:
                     print(f"Stderr: {process.stderr.strip()}", file=sys.stderr)
        return process
    except FileNotFoundError:
        cmd_name = command[0] if isinstance(command, list) else command.split()[0]
        notify(f"Error: Command '{cmd_name}' not found.", "Command Error")
        return None
    except Exception as e:
        notify(f"An unexpected error occurred while running command: {e}", "Script Error")
        return None

def notify(message, title=NOTIFY_TITLE):
    """Sends a desktop notification."""
    print(f"Notification: [{title}] {message}")
    run_command([NOTIFY_CMD, title, message], expect_output=False)

def clean_ansi(text):
    """Removes ANSI escape codes from text."""
    if not text: return ""
    return re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])').sub('', text)

def get_device():
    """Detects the Wi-Fi device or uses the default. Updates global DEVICE."""
    global DEVICE
    
    process = run_command(["iwctl", "device", "list"])
    if process and process.returncode == 0 and process.stdout:
        lines = clean_ansi(process.stdout).strip().split('\n')
        separator_count = 0
        for line in lines:
            line_stripped = line.strip()
            if not line_stripped: continue

            if separator_count < 2:
                if line_stripped.startswith("---") and line_stripped.endswith("---") and len(line_stripped) > 10:
                    separator_count += 1
                    print(f"DEBUG (get_device): Separator line #{separator_count} found: '{line_stripped}'")
                else:
                    print(f"DEBUG (get_device): Skipping pre-data line (before 2nd separator): '{line_stripped}'")
                continue
            
            if 'station' in line_stripped: 
                parts = line_stripped.split()
                if len(parts) > 0:
                    potential_device = parts[0]
                    verify_process = run_command(["iwctl", "device", potential_device, "show"])
                    if verify_process and verify_process.returncode == 0:
                        DEVICE = potential_device
                        print(f"Using device: {DEVICE}")
                        return True
    
    DEVICE = DEFAULT_DEVICE
    print(f"Could not auto-detect Wi-Fi device or detection failed, trying default: {DEVICE}")
    verify_process = run_command(["iwctl", "device", DEVICE, "show"])
    if not (verify_process and verify_process.returncode == 0):
        notify(f"Error: Default device '{DEVICE}' not found by iwctl or error accessing it.", "Device Error")
        DEVICE = None 
        return False
    print(f"Using device (default): {DEVICE}")
    return True

# --- Core Logic Functions ---

def scan_and_select_network():
    """Scans for networks, lets user select one, and sets SELECTED_SSID."""
    global SELECTED_SSID
    if not DEVICE:
        notify("No Wi-Fi device configured for scanning.", "Error")
        return False

    notify(f"Scanning for networks on {DEVICE}...")
    if not (scan_proc := run_command(["iwctl", "station", DEVICE, "scan"])) or scan_proc.returncode != 0:
        notify(f"Failed to initiate scan on {DEVICE}.", "Scan Error")
        return False
    
    time.sleep(2) 

    if not (get_networks_proc := run_command(["iwctl", "station", DEVICE, "get-networks"])) or \
       get_networks_proc.returncode != 0 or not get_networks_proc.stdout:
        notify("Failed to get networks list or list is empty.", "Scan Error")
        return False

    networks_output = clean_ansi(get_networks_proc.stdout)
    formatted_networks = []
    network_pattern = re.compile(
        r"^\s*(?:>\s*)?(.+?)\s+"                                           # SSID (Group 1)
        r"(psk|wpa-psk|wpa2-psk|wpa3-sae|sae|open|wep|802\.1x|enterprise)\s+" # Security (Group 2)
        r"([*]+)\s*$",                                                       # Signal stars (Group 3)
        re.IGNORECASE
    )
    
    separator_count = 0
    for line in networks_output.strip().split('\n'):
        line_stripped = line.strip()
        if not line_stripped: continue

        if separator_count < 2:
            if line_stripped.startswith("---") and line_stripped.endswith("---") and len(line_stripped) > 10:
                separator_count += 1
                print(f"DEBUG (scan): Separator line #{separator_count} found: '{line_stripped}'")
            else:
                print(f"DEBUG (scan): Skipping pre-data line (before 2nd separator): '{line_stripped}'")
            continue
        
        if match := network_pattern.match(line_stripped):
            ssid, security, signal_stars = match.group(1).strip(), match.group(2).strip(), match.group(3).strip()
            formatted_networks.append(f"{ssid} [{signal_stars}] ({security})")
        else:
            print(f"DEBUG (scan): Data line (after 2nd separator) did not match regex: '{line_stripped}'")

    if not formatted_networks:
        notify("No networks found or failed to parse network list.", "Scan Results")
        return False

    fuzzel_input = "\n".join(formatted_networks)
    prompt = f"Scan Results ({DEVICE}): "
    if not (selected_entry_proc := run_command(FUZZEL_CMD.split() + ["-p", prompt], input_text=fuzzel_input)) or \
       selected_entry_proc.returncode != 0 or not selected_entry_proc.stdout.strip():
        notify("No network selected from scan.", "Scan Cancelled")
        SELECTED_SSID = None
        return False
    
    selected_entry = selected_entry_proc.stdout.strip()
    SELECTED_SSID = re.sub(r'\s+\[[^\]]+\]\s+\([^)]+\)$', '', selected_entry).strip()
    print(f"Selected SSID for connection: {SELECTED_SSID}")
    return True

def list_and_select_known_network():
    """Lists known networks, lets user select one, and sets SELECTED_SSID."""
    global SELECTED_SSID
    notify("Fetching known networks...")
    
    if not (known_networks_proc := run_command(["iwctl", "known-networks", "list"])) or \
       known_networks_proc.returncode != 0 or not known_networks_proc.stdout:
        notify("Failed to get known networks list or list is empty.", "Error")
        return False

    networks_output = clean_ansi(known_networks_proc.stdout)
    formatted_known_networks = []
    known_network_pattern = re.compile(
        r"^\s*(.+?)\s+"
        r"(psk|wpa-psk|wpa2-psk|wpa3-sae|sae|open|wep|802\.1x|enterprise)"
        r"(?:\s+.*)?$",
        re.IGNORECASE
    )
    
    separator_count = 0
    for line in networks_output.strip().split('\n'):
        line_stripped = line.strip()
        if not line_stripped: continue

        if separator_count < 2:
            if line_stripped.startswith("---") and line_stripped.endswith("---") and len(line_stripped) > 10:
                separator_count += 1
                print(f"DEBUG (known): Separator line #{separator_count} found: '{line_stripped}'")
            else:
                print(f"DEBUG (known): Skipping pre-data line (before 2nd separator): '{line_stripped}'")
            continue
        
        if match := known_network_pattern.match(line_stripped):
            ssid = match.group(1).strip()
            formatted_known_networks.append(ssid)
        else:
            print(f"DEBUG (known): Data line (after 2nd separator) did not match regex: '{line_stripped}'")

    if not formatted_known_networks:
        notify("No known networks found or failed to parse.", "Known Networks")
        return False
    
    unique_networks = sorted(list(set(formatted_known_networks)))

    fuzzel_input = "\n".join(unique_networks)
    prompt_device_info = DEVICE or "global"
    prompt = f"Known Networks ({prompt_device_info}): "
    if not (selected_ssid_proc := run_command(FUZZEL_CMD.split() + ["-p", prompt], input_text=fuzzel_input)) or \
       selected_ssid_proc.returncode != 0 or not selected_ssid_proc.stdout.strip():
        notify("No known network selected.", "Action Cancelled")
        SELECTED_SSID = None
        return False
        
    SELECTED_SSID = selected_ssid_proc.stdout.strip()
    print(f"Selected known SSID: {SELECTED_SSID}")
    return True

def get_current_connection_info():
    """Checks current connection status and returns (connected_ssid, is_connected_state)"""
    if not DEVICE:
        return None, False

    status_proc = run_command(["iwctl", "station", DEVICE, "show"])
    if not status_proc or status_proc.returncode != 0 or not status_proc.stdout:
        return None, False

    output = clean_ansi(status_proc.stdout)
    connected_network_match = re.search(r"Connected network\s+(.+)", output)
    state_match = re.search(r"State\s+(connected)", output) # Specifically look for "connected" state

    current_ssid = connected_network_match.group(1).strip() if connected_network_match else None
    is_connected = bool(state_match)

    return current_ssid, is_connected


def connect_to_selected_network():
    """Connects to SELECTED_SSID, prompting for password if necessary."""
    if not DEVICE:
        notify("No Wi-Fi device configured for connection.", "Error")
        return
    if not SELECTED_SSID:
        notify("Internal error: No SSID selected for connection.", "Error")
        return

    current_connected_ssid, is_currently_connected = get_current_connection_info()

    if is_currently_connected:
        if current_connected_ssid == SELECTED_SSID:
            notify(f"Already connected to {SELECTED_SSID}. To force reconnect, disconnect first.", "Info")
            # Optionally, could add logic here to disconnect and reconnect if user insists
            # For now, just inform and exit this function.
            return
        else:
            notify(f"Currently connected to {current_connected_ssid}. Disconnecting to switch to {SELECTED_SSID}...", "Switching Network")
            if not disconnect_current_network(): # disconnect_current_network now returns True/False
                notify(f"Failed to disconnect from {current_connected_ssid}. Aborting connection to {SELECTED_SSID}.", "Error")
                return
            time.sleep(1) # Wait for interface to settle after disconnect

    # --- Proceed with connection logic ---
    is_explicitly_known = False
    if known_list_proc := run_command(["iwctl", "known-networks", "list"]):
        if known_list_proc.returncode == 0 and known_list_proc.stdout:
            parsed_known_ssids_for_check = []
            separator_count_check = 0
            temp_known_pattern = re.compile(r"^\s*(.+?)\s+(?:psk|wpa-psk|wpa2-psk|wpa3-sae|sae|open|wep|802\.1x|enterprise)(?:\s+.*)?$", re.IGNORECASE)
            for line_check in clean_ansi(known_list_proc.stdout).strip().split('\n'):
                line_s_check = line_check.strip()
                if not line_s_check: continue
                if separator_count_check < 2:
                    if line_s_check.startswith("---") and line_s_check.endswith("---"): separator_count_check += 1
                    continue
                if match_check := temp_known_pattern.match(line_s_check):
                    parsed_known_ssids_for_check.append(match_check.group(1).strip())
            if SELECTED_SSID in parsed_known_ssids_for_check:
                is_explicitly_known = True

    connect_cmd = ["iwctl", "station", DEVICE, "connect", SELECTED_SSID]
    connection_type_msg = "known" if is_explicitly_known else "potentially new"

    if not is_explicitly_known: 
        notify(f"Network '{SELECTED_SSID}' is {connection_type_msg}. It may require a password.")
        prompt_pw = f"Password for {SELECTED_SSID} (leave blank if open/stored): "
        password_proc = run_command(FUZZEL_PASSWORD_CMD.split() + ["-p", prompt_pw])
        
        if password_proc and password_proc.returncode == 0 and password_proc.stdout.strip():
            password = password_proc.stdout.strip()
            connect_cmd = ["iwctl", "--passphrase", password, "station", DEVICE, "connect", SELECTED_SSID]
            connection_type_msg += " (with provided password)"
        elif password_proc and password_proc.returncode != 0 : 
            notify(f"Password entry cancelled for {SELECTED_SSID}.", "Connection Cancelled")
            return

    notify(f"Attempting to connect to {connection_type_msg} network: {SELECTED_SSID}...")
    connect_process = run_command(connect_cmd)

    if connect_process and connect_process.returncode == 0:
        time.sleep(3) 
        status_proc = run_command(["iwctl", "station", DEVICE, "show"])
        if status_proc and status_proc.returncode == 0 and status_proc.stdout:
            status_output_clean = clean_ansi(status_proc.stdout)
            connected_match = re.search(r"Connected network\s+(.+)", status_output_clean)
            state_match = re.search(r"State\s+connected", status_output_clean)

            if connected_match and connected_match.group(1).strip() == SELECTED_SSID and state_match:
                notify(f"Successfully connected to {SELECTED_SSID}.")
            else:
                notify(f"Connection command for {SELECTED_SSID} sent, but status verification failed. Check manually.", "Connection Status")
                print(f"DEBUG: Post-connection status output:\n{status_output_clean}")
        else:
            notify(f"Connected to {SELECTED_SSID} (command successful), but failed to verify status.", "Connection Status")
    else:
        err_msg = f"Failed to connect to {SELECTED_SSID}."
        if connect_process and connect_process.stderr: err_msg += f" Error: {connect_process.stderr.strip()}"
        notify(err_msg, "Connection Failed")

def disconnect_current_network():
    """Disconnects the current Wi-Fi device. Returns True on success, False on failure."""
    if not DEVICE:
        notify("No Wi-Fi device configured for disconnection.", "Error")
        return False # Indicate failure
        
    notify(f"Disconnecting {DEVICE}...")
    disconnect_proc = run_command(["iwctl", "station", DEVICE, "disconnect"])
    if disconnect_proc and disconnect_proc.returncode == 0:
        notify(f"Successfully disconnected {DEVICE}.")
        return True # Indicate success
    else:
        notify(f"Failed to disconnect {DEVICE} (perhaps not connected or error).", "Disconnect Failed")
        return False # Indicate failure

def get_waybar_status():
    """Prints a short status string for Waybar."""
    if not get_device() or not DEVICE:
        print(f"{ICON_STATUS_DISCONNECTED} NoDev")
        return

    current_ssid, is_connected = get_current_connection_info()

    if is_connected and current_ssid:
        print(f"{ICON_STATUS_CONNECTED} {current_ssid}")
    else: # Not connected or SSID not found, check for "connecting" state
        status_proc = run_command(["iwctl", "station", DEVICE, "show"])
        if status_proc and status_proc.returncode == 0 and status_proc.stdout:
            output = clean_ansi(status_proc.stdout)
            state_match = re.search(r"State\s+(.+)", output)
            current_state_raw = state_match.group(1).strip().lower() if state_match else None
            if current_state_raw == "connecting":
                print(f"{ICON_STATUS_CONNECTING}")
                return
        # If not "connecting" and not "connected", assume disconnected or error
        print(f"{ICON_STATUS_DISCONNECTED} Off")


def main_menu():
    """Displays the main Fuzzel menu for Wi-Fi operations."""
    if not get_device() or not DEVICE: 
        notify("Critical Error: Wi-Fi device could not be determined for menu. Exiting.", "Startup Error")
        return

    options = [f"{ICON_SCAN} Scan & Connect", f"{ICON_KNOWN} Known Networks", f"{ICON_DISCONNECT} Disconnect", f"{ICON_EXIT} Exit"]
    fuzzel_input = "\n".join(options)
    prompt = f"iwctl Menu ({DEVICE}): "
    
    if not (choice_proc := run_command(FUZZEL_CMD.split() + ["-p", prompt], input_text=fuzzel_input)) or \
       choice_proc.returncode != 0 or not choice_proc.stdout.strip():
        notify("Action cancelled or no choice made.", "Menu Exit")
        return

    choice = choice_proc.stdout.strip()
    global SELECTED_SSID 
    SELECTED_SSID = None 

    if choice == f"{ICON_SCAN} Scan & Connect":
        if scan_and_select_network(): connect_to_selected_network()
    elif choice == f"{ICON_KNOWN} Known Networks":
        if list_and_select_known_network(): connect_to_selected_network()
    elif choice == f"{ICON_DISCONNECT} Disconnect":
        disconnect_current_network()
    elif choice == f"{ICON_EXIT} Exit":
        notify("Exited iwctl Menu.", "Menu Exit")
    else:
        if choice: notify(f"Invalid option selected: {choice}", "Menu Error")

# --- Main Execution ---
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Manage Wi-Fi connections using iwctl and fuzzel.")
    parser.add_argument("--status", action="store_true", help="Output a short status string for Waybar.")
    args = parser.parse_args()

    if not args.status and not get_device():
        pass

    if args.status:
        get_waybar_status()
    else:
        if "fuzzel" not in FUZZEL_CMD.lower() and "dmenu" not in FUZZEL_CMD.lower():
            print(f"Warning: FUZZEL_CMD ('{FUZZEL_CMD}') might not be a dmenu-compatible launcher.", file=sys.stderr)
        main_menu()

