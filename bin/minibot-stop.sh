#!/bin/bash
# minibot-stop.sh
# Stop all Minibot services

set -euo pipefail

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    echo "Usage: $(basename "$0")"
    echo "  Stop all Minibot services."
    exit 0
fi

COMPOSE_FILE="$(cd "$(dirname "$0")/.." && pwd)/docker/docker-compose.yml"

echo "Stopping Minibot services..."
docker compose -f "$COMPOSE_FILE" down

echo "✓ Services stopped."
