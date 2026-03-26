#!/bin/bash
# minibot-llm-start.sh
# Start the llama.cpp server inside a macOS sandbox.
# The server binds to 127.0.0.1:8012 and exposes an OpenAI-compatible API.

set -euo pipefail

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    echo "Usage: $(basename "$0")"
    echo "  Start the sandboxed llama.cpp server (Mistral 7B, localhost:8012)."
    exit 0
fi

umask 077

MINIBOT_DIR="$HOME/minibot"
LLAMA_SERVER="/opt/homebrew/bin/llama-server"
MODEL_DIR="$MINIBOT_DIR/data/models"
MODEL_FILE="$MODEL_DIR/mistral-7b-instruct-v0.3.Q4_K_M.gguf"
SANDBOX_PROFILE="$MINIBOT_DIR/etc/llama-sandbox.sb"
PID_FILE="$MINIBOT_DIR/data/llm/llama.pid"
LOG_DIR="$MINIBOT_DIR/data/logs/system"

HOST="127.0.0.1"
PORT="8012"
CTX_SIZE="4096"

# ── Preflight checks ─────────────────────────────────────────────────────────

if [ ! -x "$LLAMA_SERVER" ]; then
    echo "Error: llama-server not found at $LLAMA_SERVER" >&2
    echo "Install with: brew install llama.cpp" >&2
    exit 1
fi

if [ ! -f "$MODEL_FILE" ]; then
    echo "Error: Model file not found: $MODEL_FILE" >&2
    echo "Run: ~/minibot/scripts/install-llama-cpp.sh" >&2
    exit 1
fi

if [ ! -f "$SANDBOX_PROFILE" ]; then
    echo "Error: Sandbox profile not found: $SANDBOX_PROFILE" >&2
    exit 1
fi

# ── Check if already running ─────────────────────────────────────────────────

if [ -f "$PID_FILE" ]; then
    existing_pid=$(cat "$PID_FILE")
    if kill -0 "$existing_pid" 2>/dev/null; then
        echo "llama.cpp server is already running (PID $existing_pid)."
        echo "Stop it first: mb-llm-stop"
        exit 0
    else
        echo "Stale PID file found (PID $existing_pid no longer running). Cleaning up."
        rm -f "$PID_FILE"
    fi
fi

# ── Start the server ─────────────────────────────────────────────────────────

mkdir -p "$(dirname "$PID_FILE")" "$LOG_DIR"

echo "Starting llama.cpp server (Mistral 7B Q4_K_M)..."
echo "  Host: $HOST:$PORT"
echo "  Context: $CTX_SIZE tokens"
echo "  Sandbox: $SANDBOX_PROFILE"

sandbox-exec -f "$SANDBOX_PROFILE" -D "MODEL_DIR=$MODEL_DIR" \
    "$LLAMA_SERVER" \
    --host "$HOST" \
    --port "$PORT" \
    --model "$MODEL_FILE" \
    --ctx-size "$CTX_SIZE" \
    >> "$LOG_DIR/llama-stdout.log" 2>> "$LOG_DIR/llama-stderr.log" &

LLAMA_PID=$!
echo "$LLAMA_PID" > "$PID_FILE"

# Wait briefly and verify it didn't crash on startup
sleep 2
if kill -0 "$LLAMA_PID" 2>/dev/null; then
    echo "✓ llama.cpp server started (PID $LLAMA_PID)."
    echo ""
    echo "API endpoint:  http://$HOST:$PORT/v1/chat/completions"
    echo "Health check:  curl http://$HOST:$PORT/health"
    echo "View logs:     tail -f $LOG_DIR/llama-stdout.log"
    echo "Stop:          mb-llm-stop"
else
    echo "Error: llama.cpp server exited immediately." >&2
    echo "Check logs: tail $LOG_DIR/llama-stderr.log" >&2
    rm -f "$PID_FILE"
    exit 1
fi
