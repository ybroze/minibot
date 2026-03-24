#!/bin/bash
# uninstall-launchagent-rustdesk.sh
# Remove the RustDesk LaunchAgent so it no longer starts on login.

set -euo pipefail

PLIST_NAME="com.minibot.rustdesk"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

if [ ! -f "$PLIST_PATH" ]; then
    echo "LaunchAgent not found at: $PLIST_PATH"
    echo "Nothing to uninstall."
    exit 0
fi

GUI_UID=$(id -u)
launchctl bootout "gui/$GUI_UID/$PLIST_NAME" 2>/dev/null || true

rm -f "$PLIST_PATH"

echo "✓ RustDesk LaunchAgent removed."
echo "  RustDesk will no longer start automatically on login."
