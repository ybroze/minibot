#!/bin/bash
# minibot-llm-stop.sh
# Stop the llama.cpp server.

set -euo pipefail

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    echo "Usage: $(basename "$0")"
    echo "  Stop the llama.cpp server."
    exit 0
fi

PID_FILE="$HOME/minibot/data/llm/llama.pid"
SHUTDOWN_TIMEOUT=10

if [ ! -f "$PID_FILE" ]; then
    echo "llama.cpp server is not running (no PID file)."
    exit 0
fi

pid=$(cat "$PID_FILE")

if ! kill -0 "$pid" 2>/dev/null; then
    echo "llama.cpp server is not running (stale PID $pid). Cleaning up."
    rm -f "$PID_FILE"
    exit 0
fi

echo "Stopping llama.cpp server (PID $pid)..."
kill "$pid"

# Wait for graceful shutdown
elapsed=0
while kill -0 "$pid" 2>/dev/null; do
    if [ "$elapsed" -ge "$SHUTDOWN_TIMEOUT" ]; then
        echo "Server did not stop within ${SHUTDOWN_TIMEOUT}s. Sending SIGKILL."
        kill -9 "$pid" 2>/dev/null || true
        break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

rm -f "$PID_FILE"
echo "✓ llama.cpp server stopped."
