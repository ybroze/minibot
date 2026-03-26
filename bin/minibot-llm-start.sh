#!/bin/bash
# minibot-llm-start.sh
# Check that Ollama is running (managed by the 'ollama' user).
# The minibot user cannot start/stop Ollama — this script only checks status.

set -euo pipefail

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    echo "Usage: $(basename "$0")"
    echo "  Check Ollama status (localhost:11434). Ollama is managed by the 'ollama' user."
    exit 0
fi

MODEL="llama3.1:8b"

if ! curl -s --max-time 2 http://127.0.0.1:11434/ &>/dev/null; then
    echo "Ollama is not running." >&2
    echo "  Ollama is managed by the 'ollama' user account."
    echo "  It should start automatically when that user logs in."
    echo "  To check: ssh ollama@localhost or log in via Screen Sharing."
    exit 1
fi

echo "✓ Ollama is running."

# Check model via API (doesn't require ollama binary in our PATH)
if curl -s --max-time 5 http://127.0.0.1:11434/api/tags 2>/dev/null | grep -q "llama3.1"; then
    echo "✓ Model $MODEL is available."
else
    echo "⚠ Ollama is running but $MODEL may not be loaded."
    echo "  Log in as 'ollama' and run: ollama pull $MODEL"
fi

echo ""
echo "API endpoint:  http://127.0.0.1:11434/v1/chat/completions"
echo "From Docker:   http://host.docker.internal:11434/v1/chat/completions"
