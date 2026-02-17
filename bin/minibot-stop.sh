#!/bin/bash
# minibot-stop.sh
# Stop all Minibot services

set -euo pipefail

cd "$(dirname "$0")/.."

echo "Stopping Minibot services..."
docker compose -f docker/docker-compose.yml down

echo "✓ Services stopped."
