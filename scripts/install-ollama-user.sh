#!/bin/bash
# install-ollama-user.sh
# Setup script for the dedicated 'ollama' user account.
# Run this as the 'ollama' user. It installs the Ollama LaunchAgent
# and pulls the Llama 3.1 8B model. This user runs nothing else —
# no Docker, no secrets, no minibot scripts.

set -euo pipefail

# Ensure Homebrew is in PATH (fresh user login may not have it)
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL="llama3.1:8b"
LOG_DIR="$HOME/ollama-data/logs"

echo "=== Ollama User Setup ==="
echo ""
echo "This script will:"
echo "  1. Create a minimal directory structure"
echo "  2. Install the Ollama LaunchAgent (auto-start on login)"
echo "  3. Pull the $MODEL model (~4.9 GB)"
echo ""
read -r -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Setup cancelled."
    exit 0
fi

# ── Step 1: Check Ollama is installed ────────────────────────────────────────

echo ""
echo "Step 1: Checking Ollama..."
if command -v ollama &>/dev/null; then
    echo "✓ Ollama installed: $(which ollama)"
else
    echo "Error: ollama not found." >&2
    echo "Install as admin: brew install ollama" >&2
    exit 1
fi

# ── Step 2: Create directory structure ───────────────────────────────────────

echo ""
echo "Step 2: Creating directory structure..."
mkdir -p "$LOG_DIR"
mkdir -p "$HOME/Library/LaunchAgents"
echo "✓ Directories created"

# ── Step 3: Install LaunchAgent ──────────────────────────────────────────────

echo ""
echo "Step 3: Installing Ollama LaunchAgent..."

PLIST_NAME="com.ollama.serve"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
OLLAMA_PATH=$(command -v ollama || echo "/opt/homebrew/bin/ollama")

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

echo "✓ LaunchAgent installed: $PLIST_PATH"

# ── Step 4: Start Ollama and pull model ──────────────────────────────────────

echo ""
echo "Step 4: Pulling $MODEL..."

# Wait for LaunchAgent to start Ollama
echo -n "  Waiting for Ollama"
for i in $(seq 1 30); do
    if curl -s --max-time 1 http://127.0.0.1:11434/ &>/dev/null; then
        echo " ready."
        break
    fi
    echo -n "."
    sleep 1
done

if ! curl -s --max-time 2 http://127.0.0.1:11434/ &>/dev/null; then
    echo ""
    echo "Error: Ollama did not start within 30s." >&2
    echo "Check logs: tail $LOG_DIR/ollama-stderr.log" >&2
    exit 1
fi

if ollama list 2>/dev/null | grep -q "llama3.1:8b"; then
    echo "✓ Model $MODEL is already downloaded."
else
    echo "  This downloads ~4.9 GB — may take a while on slow connections."
    echo ""
    ollama pull "$MODEL"
    echo "✓ Model $MODEL pulled."
fi

# ── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo "=== Ollama User Setup Complete! ==="
echo ""
echo "  Ollama runs automatically on login (KeepAlive)."
echo "  API endpoint: http://127.0.0.1:11434/v1/chat/completions"
echo "  Model: $MODEL"
echo "  Logs: $LOG_DIR/"
echo ""
echo "Next: Log in as 'minibot' and run install.sh"
