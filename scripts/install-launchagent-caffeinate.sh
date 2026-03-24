#!/bin/bash
# install-launchagent-caffeinate.sh
# Install a macOS LaunchAgent that runs `caffeinate -s` to prevent system
# sleep even when idle. Belt-and-suspenders alongside pmset settings.
#
# The -s flag prevents the system from sleeping (as opposed to -d which
# only prevents display sleep). KeepAlive ensures it restarts if killed.

set -euo pipefail

PLIST_NAME="com.minibot.caffeinate"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
LOG_DIR="$HOME/minibot/data/logs/system"

mkdir -p "$LOG_DIR"
mkdir -p "$HOME/Library/LaunchAgents"

GUI_UID=$(id -u)
ALREADY_LOADED=false
if launchctl list "$PLIST_NAME" &>/dev/null; then
    ALREADY_LOADED=true
fi

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>

    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/caffeinate</string>
        <string>-s</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>${LOG_DIR}/caffeinate-stdout.log</string>

    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/caffeinate-stderr.log</string>
</dict>
</plist>
EOF

if $ALREADY_LOADED; then
    echo "✓ Plist updated.  Agent is already loaded; unload/reload to apply changes."
else
    launchctl bootstrap "gui/$GUI_UID" "$PLIST_PATH"
fi

echo "✓ Caffeinate LaunchAgent installed at: $PLIST_PATH"
echo "  System sleep is prevented (caffeinate -s). Restarts automatically if killed."
echo ""
echo "To check status:  launchctl list | grep minibot"
echo "To uninstall:     ~/minibot/scripts/uninstall-launchagent-caffeinate.sh"
