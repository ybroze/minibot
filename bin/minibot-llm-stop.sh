#!/bin/bash
# minibot-llm-stop.sh
# Stop the Ollama service.

set -euo pipefail

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    echo "Usage: $(basename "$0")"
    echo "  Stop the Ollama service."
    exit 0
fi

echo "Stopping Ollama..."
brew services stop ollama
echo "✓ Ollama stopped."
