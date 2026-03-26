#!/bin/bash
# install-ollama.sh
# Verify Ollama is installed and running (managed by the 'ollama' user).
# Cleans up any leftover files from the old llama.cpp / minibot-managed setup.
# Run as the minibot user during install.sh.

set -euo pipefail

# ── Step 1: Check Ollama binary exists ───────────────────────────────────────

echo "Checking for Ollama..."
if command -v ollama &>/dev/null; then
    echo "✓ Ollama installed: $(which ollama)"
else
    echo "Error: ollama not found." >&2
    echo "Install as admin: brew install ollama" >&2
    exit 1
fi

# ── Step 2: Clean up old llama.cpp / minibot-managed Ollama files ────────────

# Remove stale LaunchAgents from previous setups
for OLD_PLIST in "com.minibot.llama" "com.minibot.ollama"; do
    if launchctl list "$OLD_PLIST" &>/dev/null; then
        echo "Removing old LaunchAgent: $OLD_PLIST"
        GUI_UID=$(id -u)
        launchctl bootout "gui/$GUI_UID/$OLD_PLIST" 2>/dev/null || true
    fi
    rm -f "$HOME/Library/LaunchAgents/${OLD_PLIST}.plist"
done

# Remove old directories from llama.cpp era
rm -rf "$HOME/minibot/data/models" "$HOME/minibot/data/llm" "$HOME/minibot/etc" 2>/dev/null || true

# ── Step 3: Verify Ollama is running ─────────────────────────────────────────

echo ""
if curl -s --max-time 2 http://127.0.0.1:11434/ &>/dev/null; then
    echo "✓ Ollama is running on port 11434 (managed by 'ollama' user)."
    if curl -s --max-time 5 http://127.0.0.1:11434/api/tags 2>/dev/null | grep -q "llama3.1"; then
        echo "✓ Model llama3.1:8b is available."
    else
        echo "⚠ Ollama is running but llama3.1:8b may not be loaded."
        echo "  Log in as 'ollama' and run: ollama pull llama3.1:8b"
    fi
else
    echo "⚠ Ollama is not running."
    echo "  Ollama is managed by the 'ollama' user account."
    echo "  Log in as 'ollama' and run: ~/Downloads/minibot/scripts/install-ollama-user.sh"
fi
