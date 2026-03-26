#!/bin/bash
# install-launchagent-llama.sh
# Install a macOS LaunchAgent that runs the llama.cpp server inside a sandbox.
# The server binds to 127.0.0.1:8012 and auto-restarts on crash (KeepAlive).

set -euo pipefail

PLIST_NAME="com.minibot.llama"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
LOG_DIR="$HOME/minibot/data/logs/system"
MODEL_DIR="$HOME/minibot/data/models"
MODEL_FILE="$MODEL_DIR/Mistral-7B-Instruct-v0.3-Q4_K_M.gguf"
SANDBOX_PROFILE="$HOME/minibot/etc/llama-sandbox.sb"

if [ ! -f "$MODEL_FILE" ]; then
    echo "Error: Model file not found: $MODEL_FILE" >&2
    echo "Run install-llama-cpp.sh first." >&2
    exit 1
fi

if [ ! -f "$SANDBOX_PROFILE" ]; then
    echo "Error: Sandbox profile not found: $SANDBOX_PROFILE" >&2
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
        <string>/usr/bin/sandbox-exec</string>
        <string>-f</string>
        <string>${SANDBOX_PROFILE}</string>
        <string>-D</string>
        <string>MODEL_DIR=${MODEL_DIR}</string>
        <string>/opt/homebrew/bin/llama-server</string>
        <string>--host</string>
        <string>127.0.0.1</string>
        <string>--port</string>
        <string>8012</string>
        <string>--model</string>
        <string>${MODEL_FILE}</string>
        <string>--ctx-size</string>
        <string>4096</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>${LOG_DIR}/llama-stdout.log</string>

    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/llama-stderr.log</string>

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

echo "✓ llama.cpp LaunchAgent installed at: $PLIST_PATH"
echo "  Server will start automatically on login (127.0.0.1:8012)."
echo "  Auto-restarts on crash (KeepAlive)."
echo ""
echo "To check status:  launchctl list | grep minibot"
echo "To uninstall:     launchctl bootout gui/$GUI_UID/$PLIST_NAME"
