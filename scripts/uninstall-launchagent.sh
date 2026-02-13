#!/bin/bash
# uninstall-launchagent.sh
# Remove the Minibot LaunchAgent so services no longer start on login.

set -euo pipefail

PLIST_NAME="com.minibot.gateway"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

if [ ! -f "$PLIST_PATH" ]; then
    echo "LaunchAgent not found at: $PLIST_PATH"
    echo "Nothing to uninstall."
    exit 0
fi

# Unload the agent
launchctl unload "$PLIST_PATH" 2>/dev/null || true

# Remove the plist
rm -f "$PLIST_PATH"

echo "✓ LaunchAgent removed."
echo "  Minibot will no longer start automatically on login."
