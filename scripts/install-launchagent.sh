#!/bin/bash
# install-launchagent.sh
# Install a macOS LaunchAgent so Minibot services start on login.
#
# The agent runs minibot-start.sh once at load time.
# Logs go to ~/minibot/data/logs/system/.

set -euo pipefail

PLIST_NAME="com.minibot.gateway"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
LOG_DIR="$HOME/minibot/data/logs/system"
START_SCRIPT="$HOME/minibot/bin/minibot-start.sh"

if [ ! -x "$START_SCRIPT" ]; then
    echo "Error: $START_SCRIPT not found or not executable." >&2
    echo "Run install.sh first." >&2
    exit 1
fi

mkdir -p "$LOG_DIR"
mkdir -p "$HOME/Library/LaunchAgents"

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
        <string>/bin/bash</string>
        <string>${START_SCRIPT}</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <false/>

    <key>StandardOutPath</key>
    <string>${LOG_DIR}/launchagent-stdout.log</string>

    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/launchagent-stderr.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF

# Load the agent (bootstrap is the modern replacement for load)
GUI_UID=$(id -u)
launchctl bootstrap "gui/$GUI_UID" "$PLIST_PATH" 2>/dev/null || true

echo "✓ LaunchAgent installed at: $PLIST_PATH"
echo "  Minibot will start automatically on login."
echo ""
echo "To check status:  launchctl list | grep minibot"
echo "To uninstall:     ~/minibot/scripts/uninstall-launchagent.sh"
echo ""
echo "Recommended: Prevent automatic sleep for 24/7 operation:"
echo "  System Settings > Energy > Prevent automatic sleeping when the display is off > ON"
