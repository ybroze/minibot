#!/bin/bash
# install-ollama.sh
# Verify Ollama is installed (by admin), pull the Llama 3.1 8B model,
# and clean up any leftover llama.cpp files from the previous setup.
# Idempotent — skips steps that are already complete.

set -euo pipefail

MODEL="llama3.1:8b"
LOG_DIR="$HOME/minibot/data/logs/system"

# ── Step 1: Check for Ollama ─────────────────────────────────────────────────

echo "Checking for Ollama..."
if command -v ollama &>/dev/null; then
    echo "✓ Ollama installed: $(which ollama)"
else
    echo "Error: ollama not found." >&2
    echo "Install as admin: brew install ollama" >&2
    exit 1
fi

# ── Step 2: Clean up old llama.cpp files ─────────────────────────────────────

# Remove stale LaunchAgent from the old llama.cpp setup
OLD_PLIST="com.minibot.llama"
if launchctl list "$OLD_PLIST" &>/dev/null; then
    echo "Removing old llama.cpp LaunchAgent..."
    GUI_UID=$(id -u)
    launchctl bootout "gui/$GUI_UID/$OLD_PLIST" 2>/dev/null || true
fi
rm -f "$HOME/Library/LaunchAgents/${OLD_PLIST}.plist"

# Remove old directories and files
if [ -d "$HOME/minibot/data/models" ]; then
    echo "Cleaning up old model files..."
    rm -rf "$HOME/minibot/data/models"
fi
rm -rf "$HOME/minibot/data/llm" "$HOME/minibot/etc" 2>/dev/null || true

# ── Step 3: Start Ollama temporarily to pull the model ───────────────────────

mkdir -p "$LOG_DIR"

STARTED_HERE=false
if curl -s --max-time 2 http://127.0.0.1:11434/ &>/dev/null; then
    echo "✓ Ollama is already running."
else
    echo "Starting Ollama temporarily for model download..."
    ollama serve >> "$LOG_DIR/ollama-stdout.log" 2>> "$LOG_DIR/ollama-stderr.log" &
    STARTED_HERE=true

    for i in $(seq 1 30); do
        if curl -s --max-time 1 http://127.0.0.1:11434/ &>/dev/null; then
            break
        fi
        sleep 1
    done

    if ! curl -s --max-time 2 http://127.0.0.1:11434/ &>/dev/null; then
        echo "Error: Ollama did not start." >&2
        echo "Check logs: tail $LOG_DIR/ollama-stderr.log" >&2
        exit 1
    fi
    echo "✓ Ollama started."
fi

# ── Step 4: Pull the model ───────────────────────────────────────────────────

if ollama list 2>/dev/null | grep -q "llama3.1:8b"; then
    echo "✓ Model $MODEL is already downloaded."
else
    echo ""
    echo "Pulling $MODEL..."
    echo "  This downloads ~4.9 GB — may take a while on slow connections."
    echo ""
    ollama pull "$MODEL"
    echo "✓ Model $MODEL pulled."
fi

# Stop the temporary server if we started it (LaunchAgent will manage it)
if $STARTED_HERE; then
    pkill -f "ollama serve" 2>/dev/null || true
    echo "  (temporary Ollama server stopped)"
fi

echo ""
echo "✓ Ollama setup complete."
echo "  Start: mb-llm-start"
