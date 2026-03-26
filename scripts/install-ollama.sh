#!/bin/bash
# install-ollama.sh
# Install Ollama via Homebrew and pull the Llama 3.1 8B model.
# Idempotent — skips steps that are already complete.

set -euo pipefail

MODEL="llama3.1:8b"

# ── Step 1: Check for Ollama ─────────────────────────────────────────────────

echo "Checking for Ollama..."
if command -v ollama &>/dev/null; then
    echo "✓ Ollama already installed: $(which ollama)"
else
    echo "Installing Ollama via Homebrew..."
    BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
    if [ -w "$BREW_PREFIX/bin" ]; then
        brew install ollama
        echo "✓ Ollama installed"
    else
        if dseditgroup -o checkmember -m "$(whoami)" admin &>/dev/null; then
            echo "Admin privileges required for Homebrew packages."
            if sudo -u "$(stat -f '%Su' "$BREW_PREFIX/bin")" brew install ollama; then
                echo "✓ Ollama installed"
            else
                echo "Error: Could not install Ollama." >&2
                echo "Install manually as admin: brew install ollama" >&2
                exit 1
            fi
        else
            echo "Error: Standard user cannot install Homebrew packages." >&2
            echo "Install as admin: brew install ollama" >&2
            exit 1
        fi
    fi
fi

# ── Step 2: Start Ollama temporarily to pull the model ───────────────────────

OLLAMA_RUNNING=false
if curl -s --max-time 2 http://127.0.0.1:11434/ &>/dev/null; then
    OLLAMA_RUNNING=true
    echo "✓ Ollama server is already running."
else
    echo "Starting Ollama server temporarily for model download..."
    mkdir -p "$HOME/minibot/data/logs/system"
    ollama serve >> "$HOME/minibot/data/logs/system/ollama-stdout.log" \
                 2>> "$HOME/minibot/data/logs/system/ollama-stderr.log" &
    OLLAMA_PID=$!

    # Wait for server to be ready
    for i in $(seq 1 30); do
        if curl -s --max-time 1 http://127.0.0.1:11434/ &>/dev/null; then
            break
        fi
        sleep 1
    done

    if ! curl -s --max-time 2 http://127.0.0.1:11434/ &>/dev/null; then
        echo "Error: Ollama server did not start." >&2
        echo "Check logs: tail ~/minibot/data/logs/system/ollama-stderr.log" >&2
        kill "$OLLAMA_PID" 2>/dev/null || true
        exit 1
    fi
fi

# ── Step 3: Pull the model ───────────────────────────────────────────────────

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

# Stop the temporary server if we started it
if ! $OLLAMA_RUNNING && [ -n "${OLLAMA_PID:-}" ]; then
    kill "$OLLAMA_PID" 2>/dev/null || true
    echo "  (temporary Ollama server stopped)"
fi

echo ""
echo "✓ Ollama setup complete."
echo "  Start the server with: mb-llm-start"
