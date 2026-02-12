#!/bin/bash
# minibot-start.sh
# Start all Minibot services via Docker Compose

set -e

cd "$(dirname "$0")/.."

echo "Starting Minibot services..."
docker-compose -f docker/docker-compose.yml up -d

echo "✓ Services started."
echo ""
echo "Check status with:"
echo "  docker-compose -f docker/docker-compose.yml ps"
echo ""
echo "View logs with:"
echo "  ~/minibot/bin/minibot-logs.sh"
