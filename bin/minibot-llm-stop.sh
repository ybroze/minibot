#!/bin/bash
# minibot-llm-stop.sh
# Ollama is managed by the 'ollama' user — the minibot user cannot stop it.

set -euo pipefail

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    echo "Usage: $(basename "$0")"
    echo "  Ollama is managed by the 'ollama' user account."
    exit 0
fi

echo "Ollama is managed by the 'ollama' user account."
echo "The minibot user cannot start or stop it."
echo ""
echo "To stop Ollama, log in as 'ollama' and run:"
echo "  pkill -f 'ollama serve'"
echo ""
echo "Or unload the LaunchAgent:"
echo "  launchctl bootout gui/\$(id -u)/com.ollama.serve"
