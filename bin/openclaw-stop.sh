#!/bin/bash
# openclaw-stop.sh
# Stop all OpenClaw services

set -e

cd "$(dirname "$0")/.."

echo "Stopping OpenClaw services..."
docker-compose -f docker/docker-compose.yml down

echo "✓ Services stopped."
