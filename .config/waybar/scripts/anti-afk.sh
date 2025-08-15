#!/bin/bash
# Anti-AFK script for Hyprland (Wayland) using ydotool
# By default integrates with Waybar

set -euo pipefail

SCRIPT_DIR="$HOME/.config/waybar/scripts"
PID_FILE="$SCRIPT_DIR/.anti-afk.pid"
STATUS_FILE="$SCRIPT_DIR/.anti-afk.status"
export YDOTOOL_SOCKET="/run/user/$(id -u)/.ydotool_socket"

mkdir -p "$SCRIPT_DIR"

# --- Helpers ---

generate_random_delay() {
    awk 'BEGIN {srand(); printf "%.3f", 2 + rand() * 2}'
}

send_enter() {
    ydotool key 28:1 28:0
}

perform_anti_afk_sequence() {
    echo "pressing" > "$STATUS_FILE"
    for _ in {1..4}; do
        send_enter
        sleep "$(generate_random_delay)"
    done
    echo "active" > "$STATUS_FILE"
}

status_json() {
    printf '{"text": "%s", "class": "%s", "tooltip": "%s"}\n' "$@"
}

# --- Daemon Loop ---

anti_afk_daemon() {
    # Ensure cleanup on exit of the daemon
    trap 'echo "inactive" > "$STATUS_FILE"; rm -f "$PID_FILE"' EXIT

    echo "active" > "$STATUS_FILE"
    perform_anti_afk_sequence

    while :; do
        # Wait between 18 and 20 minutes, but remain responsive to stop requests
        for ((elapsed=0, wait=$((RANDOM % 121 + 1080)); elapsed < wait; elapsed+=10)); do
            sleep 10
            [[ -f "$PID_FILE" ]] || exit 0
        done
        perform_anti_afk_sequence
    done
}

# --- Controls ---

is_running() {
    # Return 0 if a live process matches the PID in PID_FILE; else cleanup and return 1
    [[ -f "$PID_FILE" ]] || return 1
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
        return 0
    else
        rm -f "$PID_FILE"
        echo "inactive" > "$STATUS_FILE"
        return 1
    fi
}

start_anti_afk() {
    if is_running; then
        return 1
    fi

    # Start daemon in background and record its PID
    anti_afk_daemon &
    local daemon_pid=$!
    echo "$daemon_pid" > "$PID_FILE"

    # Optional: disown the daemon so it persists independently
    disown "$daemon_pid" 2>/dev/null || true

    # Quick health check: ensure the daemon is actually alive
    sleep 0.2
    if kill -0 "$daemon_pid" 2>/dev/null; then
        echo "active" > "$STATUS_FILE"
        return 0
    else
        rm -f "$PID_FILE"
        echo "inactive" > "$STATUS_FILE"
        return 1
    fi
}

stop_anti_afk() {
    if ! [[ -f "$PID_FILE" ]]; then
        echo "inactive" > "$STATUS_FILE"
        return 1
    fi
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
        # Try graceful stop first
        kill "$pid" 2>/dev/null || true
        # Short wait, then force if needed
        sleep 0.3
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null || true
        fi
    fi
    rm -f "$PID_FILE"
    echo "inactive" > "$STATUS_FILE"
    return 0
}

toggle_anti_afk() {
    if is_running; then
        stop_anti_afk
    else
        start_anti_afk
    fi
}

get_status() {
    if is_running; then
        case "$(cat "$STATUS_FILE" 2>/dev/null || echo active)" in
            pressing) status_json "🔄" "pressing" "Anti-AFK: Pressing keys..." ;;
            active|*) status_json "🟢" "active" "Anti-AFK: ON (Click to turn OFF)" ;;
        esac
    else
        status_json "🔴" "inactive" "Anti-AFK: OFF (Click to turn ON)"
    fi
}

# --- CLI ---

[[ -f "$STATUS_FILE" ]] || echo "inactive" > "$STATUS_FILE"

case "${1:-status}" in
    toggle) toggle_anti_afk ;;
    start)  start_anti_afk ;;
    stop)   stop_anti_afk ;;
    status) get_status ;;
    test)   perform_anti_afk_sequence ;;
    debug)
        echo "PID file exists: $([[ -f "$PID_FILE" ]] && echo yes || echo no)"
        if [[ -f "$PID_FILE" ]]; then
            echo "PID: $(cat "$PID_FILE")"
            echo "Process running: $(is_running && echo yes || echo no)"
        fi
        echo "Status: $(cat "$STATUS_FILE" 2>/dev/null || echo missing)"
        ;;
    *)
        echo "Usage: $0 {toggle|start|stop|status|test|debug}" >&2
        exit 2
        ;;
esac
