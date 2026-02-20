#!/bin/bash
# minibot-start.sh
# Start all Minibot services via Docker Compose.
# Secrets are loaded from the macOS Keychain (also loaded on login by zshrc-additions.sh).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

# --- Verify Docker is running ----------------------------------------------
if ! docker info &>/dev/null; then
    echo "Error: Docker is not running. Start Docker Desktop first." >&2
    exit 1
fi

# --- Load secrets from keychain into the environment -----------------------
echo "Loading secrets from keychain..."
eval "$("$SCRIPT_DIR/minibot-secrets.sh" export)"

# Verify required secrets are present
missing=0
for key in POSTGRES_PASSWORD REDIS_PASSWORD MONGO_PASSWORD OPENCLAW_GATEWAY_PASSWORD; do
    if [ -z "${!key:-}" ]; then
        echo "Error: $key not found in keychain." >&2
        missing=1
    fi
done
if [ "$missing" -eq 1 ]; then
    echo "Run:  minibot-secrets.sh init" >&2
    exit 1
fi

# --- Verify openclaw:local image exists ------------------------------------
if ! docker image inspect openclaw:local &>/dev/null; then
    echo "Error: openclaw:local image not found." >&2
    echo "Run:  ~/minibot/scripts/build-openclaw.sh" >&2
    exit 1
fi

# --- Start services --------------------------------------------------------
echo "Starting Minibot services..."
docker compose -f docker/docker-compose.yml up -d

echo "✓ Services started."
echo ""
echo "Check status with:"
echo "  docker compose -f docker/docker-compose.yml ps"
echo ""
echo "View logs with:"
echo "  ~/minibot/bin/minibot-logs.sh"
