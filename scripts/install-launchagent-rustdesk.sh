#!/bin/bash
# install-launchagent-rustdesk.sh
# Install a macOS LaunchAgent to keep RustDesk running for remote access.
#
# RustDesk must be installed and configured first (setup-rustdesk.sh).
# KeepAlive is true — RustDesk restarts automatically if it crashes,
# since it is the remote access lifeline to this machine.
# Logs go to ~/minibot/data/logs/system/.

set -euo pipefail

PLIST_NAME="com.minibot.rustdesk"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
LOG_DIR="$HOME/minibot/data/logs/system"
RUSTDESK_BIN="/Applications/RustDesk.app/Contents/MacOS/RustDesk"

if [ ! -x "$RUSTDESK_BIN" ]; then
    echo "Error: RustDesk not found at $RUSTDESK_BIN" >&2
    echo "Run: brew install --cask rustdesk" >&2
    exit 1
fi

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
        <string>${RUSTDESK_BIN}</string>
        <string>--service</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>${LOG_DIR}/rustdesk-stdout.log</string>

    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/rustdesk-stderr.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>${HOME}</string>
    </dict>
</dict>
</plist>
EOF

if $ALREADY_LOADED; then
    echo "✓ Plist updated.  Agent is already loaded; unload/reload to apply changes."
else
    launchctl bootstrap "gui/$GUI_UID" "$PLIST_PATH"
fi

echo "✓ RustDesk LaunchAgent installed at: $PLIST_PATH"
echo "  RustDesk will start automatically on login and restart if it crashes."
echo ""
echo "To check status:  launchctl list | grep minibot"
echo "To uninstall:     ~/minibot/scripts/uninstall-launchagent-rustdesk.sh"
