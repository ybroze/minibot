#!/bin/bash
# uninstall-launchagent-caffeinate.sh
# Remove the caffeinate LaunchAgent.

set -euo pipefail

PLIST_NAME="com.minibot.caffeinate"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

if [ ! -f "$PLIST_PATH" ]; then
    echo "LaunchAgent not found at: $PLIST_PATH"
    echo "Nothing to uninstall."
    exit 0
fi

GUI_UID=$(id -u)
launchctl bootout "gui/$GUI_UID/$PLIST_NAME" 2>/dev/null || true

rm -f "$PLIST_PATH"

echo "✓ Caffeinate LaunchAgent removed."
echo "  System sleep prevention via caffeinate is no longer active."
