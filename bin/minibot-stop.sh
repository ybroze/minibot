#!/bin/bash
# minibot-stop.sh
# Stop all Minibot services

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

# Load secrets so docker compose can parse the compose file
eval "$("$SCRIPT_DIR/minibot-secrets.sh" export)"

echo "Stopping Minibot services..."
docker compose -f docker/docker-compose.yml down

echo "✓ Services stopped."
