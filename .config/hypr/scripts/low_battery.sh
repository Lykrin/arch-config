#!/bin/sh

# Thresholds for notifications
WARNING_THRESHOLD=15
CRITICAL_THRESHOLD=5

# Get battery status and capacity using acpi
acpi -b | awk -F'[,:%]' '{print $2, $3}' | {
    read -r status capacity

    # Check if battery is discharging and below thresholds
    if [ "${status}" = "Discharging" ]; then
        if [ "${capacity}" -lt "${CRITICAL_THRESHOLD}" ]; then
            notify-send -u critical "Battery Critical!" "Battery at ${capacity}%. Plug in now!"
            # Play sound (adjust path to your sound file)
            mpv /home/lykrin/.config/hypr/scripts/battery_low.mp3
	elif [ "${capacity}" -lt "${WARNING_THRESHOLD}" ]; then
            notify-send -u normal "Battery Low!" "Battery at ${capacity}%. Consider plugging in."
            # Play sound (adjust path to your sound file)
            mpv /home/lykrin/.config/hypr/scripts/battery_low.mp3
        fi
    fi
}

