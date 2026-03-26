#!/bin/bash
# install-llama-cpp.sh
# Install llama.cpp via Homebrew and download the Llama 3.1 8B Q4_K_M model.
# Idempotent — skips steps that are already complete.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MINIBOT_DIR="$HOME/minibot"
MODEL_DIR="$MINIBOT_DIR/data/models"
MODEL_FILE="$MODEL_DIR/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"
# Expected size: ~4.6 GB (approximate — used for sanity check, not exact match)
MODEL_MIN_SIZE_MB=4400

# ── Step 1: Install llama.cpp via Homebrew ───────────────────────────────────

echo "Checking for llama.cpp..."
if command -v llama-server &>/dev/null; then
    echo "✓ llama-server already installed: $(which llama-server)"
else
    echo "Installing llama.cpp via Homebrew..."
    BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
    if [ -w "$BREW_PREFIX/bin" ]; then
        brew install llama.cpp
        echo "✓ llama.cpp installed"
    else
        if dseditgroup -o checkmember -m "$(whoami)" admin &>/dev/null; then
            echo "Admin privileges required for Homebrew packages."
            if sudo -u "$(stat -f '%Su' "$BREW_PREFIX/bin")" brew install llama.cpp; then
                echo "✓ llama.cpp installed"
            else
                echo "Error: Could not install llama.cpp." >&2
                echo "Install manually as admin: brew install llama.cpp" >&2
                exit 1
            fi
        else
            echo "Error: Standard user cannot install Homebrew packages." >&2
            echo "Install as admin: brew install llama.cpp" >&2
            exit 1
        fi
    fi
fi

# ── Step 2: Create directories ───────────────────────────────────────────────

mkdir -p "$MODEL_DIR"
mkdir -p "$MINIBOT_DIR/data/llm"
mkdir -p "$MINIBOT_DIR/etc"

# ── Step 3: Copy sandbox profile ─────────────────────────────────────────────

SANDBOX_SRC="$SCRIPT_DIR/../etc/llama-sandbox.sb"
SANDBOX_DST="$MINIBOT_DIR/etc/llama-sandbox.sb"

if [ -f "$SANDBOX_SRC" ]; then
    cp "$SANDBOX_SRC" "$SANDBOX_DST"
    echo "✓ Sandbox profile installed: $SANDBOX_DST"
else
    echo "Warning: Sandbox profile not found at $SANDBOX_SRC" >&2
    echo "  The llama.cpp server will not be sandboxed until this is resolved." >&2
fi

# ── Step 4: Download model ───────────────────────────────────────────────────

if [ -f "$MODEL_FILE" ]; then
    echo "✓ Model already exists: $MODEL_FILE"
    file_size_mb=$(( $(stat -f%z "$MODEL_FILE") / 1048576 ))
    echo "  Size: ${file_size_mb} MB"
    if [ "$file_size_mb" -lt "$MODEL_MIN_SIZE_MB" ]; then
        echo "Warning: Model file is smaller than expected (${MODEL_MIN_SIZE_MB} MB)." >&2
        echo "  It may be incomplete. Delete it and re-run to re-download." >&2
    fi
else
    echo ""
    echo "Downloading Llama 3.1 8B Instruct (Q4_K_M quantization)..."
    echo "  URL: $MODEL_URL"
    echo "  Destination: $MODEL_FILE"
    echo "  Size: ~4.6 GB — this will take a while."
    echo ""

    # Resumable download (-C -) in case of interruption
    if curl -L -C - --progress-bar -o "$MODEL_FILE" "$MODEL_URL"; then
        file_size_mb=$(( $(stat -f%z "$MODEL_FILE") / 1048576 ))
        echo "✓ Model downloaded: ${file_size_mb} MB"
        if [ "$file_size_mb" -lt "$MODEL_MIN_SIZE_MB" ]; then
            echo "Warning: Download may be incomplete (expected ≥${MODEL_MIN_SIZE_MB} MB)." >&2
            echo "  Delete the file and re-run to retry." >&2
        fi
    else
        echo "Error: Model download failed." >&2
        echo "  Partial file may exist at: $MODEL_FILE" >&2
        echo "  Re-run this script to resume the download." >&2
        exit 1
    fi
fi

# Make model file read-only
chmod 444 "$MODEL_FILE"

echo ""
echo "✓ llama.cpp setup complete."
echo "  Binary:  $(which llama-server)"
echo "  Model:   $MODEL_FILE"
echo "  Sandbox: $SANDBOX_DST"
