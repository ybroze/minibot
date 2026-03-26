#!/bin/bash
# install-launchagent-llama.sh
# Install a macOS LaunchAgent that runs Ollama on login.
# The server binds to 127.0.0.1:11434 and auto-restarts on crash (KeepAlive).

set -euo pipefail

PLIST_NAME="com.minibot.ollama"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
LOG_DIR="$HOME/minibot/data/logs/system"

if ! command -v ollama &>/dev/null; then
    echo "Error: ollama not found." >&2
    echo "Run install-ollama.sh first." >&2
    exit 1
fi

mkdir -p "$LOG_DIR"
mkdir -p "$HOME/Library/LaunchAgents"

GUI_UID=$(id -u)
ALREADY_LOADED=false
if launchctl list "$PLIST_NAME" &>/dev/null; then
    ALREADY_LOADED=true
fi

# Unload old llama.cpp LaunchAgent if present
OLD_PLIST="com.minibot.llama"
if launchctl list "$OLD_PLIST" &>/dev/null; then
    echo "Removing old llama.cpp LaunchAgent..."
    launchctl bootout "gui/$GUI_UID/$OLD_PLIST" 2>/dev/null || true
fi
rm -f "$HOME/Library/LaunchAgents/${OLD_PLIST}.plist"

OLLAMA_PATH=$(which ollama)

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
        <string>${OLLAMA_PATH}</string>
        <string>serve</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>${LOG_DIR}/ollama-stdout.log</string>

    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/ollama-stderr.log</string>

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

echo "✓ Ollama LaunchAgent installed at: $PLIST_PATH"
echo "  Server will start automatically on login (127.0.0.1:11434)."
echo "  Auto-restarts on crash (KeepAlive)."
echo ""
echo "To check status:  launchctl list | grep minibot"
echo "To uninstall:     launchctl bootout gui/$GUI_UID/$PLIST_NAME"
