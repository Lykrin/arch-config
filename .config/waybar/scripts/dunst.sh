#!/bin/bash

# Check if dunst is running
if ! pgrep -x "dunst" > /dev/null; then
    echo '{"text": "Dunst not running", "tooltip": "Dunst notification daemon is not running", "class": "error"}'
    exit 1
fi

# Get current status
COUNT=$(dunstctl count waiting)
PAUSED=$(dunstctl is-paused)

# Determine the appropriate icon
if [ "$PAUSED" = "true" ]; then
    if [ "$COUNT" -gt 0 ]; then
        echo '{"alt": "dnd-notification", "tooltip": "Do not disturb mode ('"$COUNT"' notifications)"}'
    else
        echo '{"alt": "dnd-none", "tooltip": "Do not disturb mode"}'
    fi
else
    if [ "$COUNT" -gt 0 ]; then
        echo '{"alt": "notification", "tooltip": "'"$COUNT"' pending notifications"}'
    else
        echo '{"alt": "none", "tooltip": "No notifications"}'
    fi
fi
