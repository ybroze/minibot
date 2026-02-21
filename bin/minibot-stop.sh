#!/bin/bash
# minibot-stop.sh
# Stop all Minibot services

set -euo pipefail

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    echo "Usage: $(basename "$0")"
    echo "  Stop all Minibot services."
    exit 0
fi

cd "$(dirname "$0")/.."

echo "Stopping Minibot services..."
docker compose -f docker/docker-compose.yml down

echo "✓ Services stopped."
