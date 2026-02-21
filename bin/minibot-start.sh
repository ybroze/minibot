#!/bin/bash
# minibot-start.sh
# Start all Minibot services via Docker Compose.
# Secrets are loaded from the macOS Keychain (also loaded on login by zshrc-additions.sh).

set -euo pipefail

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    echo "Usage: $(basename "$0")"
    echo "  Load secrets from macOS Keychain and start all Minibot services."
    exit 0
fi

# Ensure restrictive file permissions even when run outside a login shell
# (e.g., via LaunchAgent where zshrc-additions.sh is not sourced).
umask 077

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

# --- Wait for Docker to be available ----------------------------------------
DOCKER_TIMEOUT=90
DOCKER_INTERVAL=5

if docker info &>/dev/null; then
    echo "Docker is available."
else
    echo "Waiting for Docker to become available (up to ${DOCKER_TIMEOUT}s)..."
    elapsed=0
    while ! docker info &>/dev/null; do
        if [ "$elapsed" -ge "$DOCKER_TIMEOUT" ]; then
            echo "Error: Docker did not become available within ${DOCKER_TIMEOUT}s." >&2
            echo "Start Docker Desktop and try again." >&2
            exit 1
        fi
        sleep "$DOCKER_INTERVAL"
        elapsed=$((elapsed + DOCKER_INTERVAL))
        echo "  ... waiting (${elapsed}s elapsed)"
    done
    echo "Docker is available (after ${elapsed}s)."
fi

# --- Load secrets from keychain into the environment -----------------------
echo "Loading secrets from keychain..."
eval "$("$SCRIPT_DIR/minibot-secrets.sh" export)"

# Verify required secrets are present
missing=0
while IFS= read -r key; do
    if [ -z "${!key:-}" ]; then
        echo "Error: $key not found in keychain." >&2
        missing=1
    fi
done < <("$SCRIPT_DIR/minibot-secrets.sh" keys)
if [ "$missing" -eq 1 ]; then
    echo "Run:  mb-secrets init" >&2
    exit 1
fi

# --- Verify openclaw:local image exists ------------------------------------
if ! docker image inspect openclaw:local &>/dev/null; then
    echo "Error: openclaw:local image not found." >&2
    echo "Run:  mb-build" >&2
    exit 1
fi

# --- Start services --------------------------------------------------------
echo "Starting Minibot services..."
docker compose -f docker/docker-compose.yml up -d

echo "✓ Services started."
echo ""
echo "Check status:  mb-status"
echo "View logs:     mb-logs"
