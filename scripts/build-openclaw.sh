#!/bin/bash
# build-openclaw.sh
# Clone (or update) the OpenClaw source and build the openclaw:local Docker image.

set -euo pipefail

REPO_URL="https://github.com/openclaw/openclaw"
VENDOR_DIR="$HOME/minibot/vendor/openclaw"

echo "=== Build OpenClaw Docker Image ==="
echo ""

# --- Clone or update source -------------------------------------------------
if [ -d "$VENDOR_DIR/.git" ]; then
    echo "Updating OpenClaw source..."
    if ! git -C "$VENDOR_DIR" pull --ff-only; then
        echo "Error: Could not fast-forward OpenClaw source." >&2
        echo "Try: cd $VENDOR_DIR && git status" >&2
        exit 1
    fi
else
    echo "Cloning OpenClaw source to $VENDOR_DIR..."
    mkdir -p "$(dirname "$VENDOR_DIR")"
    git clone "$REPO_URL" "$VENDOR_DIR"
fi
echo ""

# --- Build image ------------------------------------------------------------
echo "Building openclaw:local..."
docker build --progress=plain -t openclaw:local -f "$VENDOR_DIR/Dockerfile" "$VENDOR_DIR"

echo ""
echo "✓ openclaw:local is ready."
echo ""
echo "Start Minibot with:"
echo "  mb-start"
