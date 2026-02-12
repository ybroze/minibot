#!/bin/bash
# openclaw-start.sh
# Start all OpenClaw services via Docker Compose

set -e

cd "$(dirname "$0")/.."

echo "Starting OpenClaw services..."
docker-compose -f docker/docker-compose.yml up -d

echo "✓ Services started."
echo ""
echo "Check status with:"
echo "  docker-compose -f docker/docker-compose.yml ps"
echo ""
echo "View logs with:"
echo "  ~/openclaw/bin/openclaw-logs.sh"
