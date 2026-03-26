#!/bin/bash
# minibot-llm-start.sh
# Start Ollama via brew services and ensure the model is pulled.
# The server binds to 127.0.0.1:11434 and exposes an OpenAI-compatible API.

set -euo pipefail

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    echo "Usage: $(basename "$0")"
    echo "  Start Ollama and load the Llama 3.1 8B model (localhost:11434)."
    exit 0
fi

MODEL="llama3.1:8b"

# ── Preflight ─────────────────────────────────────────────────────────────────

if ! command -v ollama &>/dev/null; then
    echo "Error: ollama not found." >&2
    echo "Install with: brew install ollama" >&2
    exit 1
fi

# ── Start the service ─────────────────────────────────────────────────────────

if curl -s --max-time 2 http://127.0.0.1:11434/ &>/dev/null; then
    echo "Ollama is already running."
else
    echo "Starting Ollama..."
    brew services start ollama

    echo -n "  Waiting for server"
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
        echo "Check: brew services info ollama" >&2
        exit 1
    fi
fi

# ── Ensure the model is pulled ───────────────────────────────────────────────

if ollama list 2>/dev/null | grep -q "llama3.1:8b"; then
    echo "✓ Model $MODEL is available."
else
    echo "Pulling $MODEL (this may take a few minutes on first run)..."
    ollama pull "$MODEL"
    echo "✓ Model $MODEL pulled."
fi

echo ""
echo "✓ Ollama is running with $MODEL."
echo ""
echo "API endpoint:  http://127.0.0.1:11434/v1/chat/completions"
echo "Health check:  mb-llm-status"
echo "Chat:          ollama run $MODEL"
echo "Stop:          mb-llm-stop"
