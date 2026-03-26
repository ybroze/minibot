#!/bin/bash
# minibot-llm-stop.sh
# Stop the Ollama server.

set -euo pipefail

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    echo "Usage: $(basename "$0")"
    echo "  Stop the Ollama server."
    exit 0
fi

if ! curl -s --max-time 2 http://127.0.0.1:11434/ &>/dev/null; then
    echo "Ollama is not running."
    exit 0
fi

echo "Stopping Ollama..."
pkill -f "ollama serve" 2>/dev/null || true

for i in $(seq 1 10); do
    if ! curl -s --max-time 1 http://127.0.0.1:11434/ &>/dev/null; then
        echo "✓ Ollama stopped."
        exit 0
    fi
    sleep 1
done

echo "Warning: Ollama may still be running." >&2
