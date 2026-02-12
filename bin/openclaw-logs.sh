#!/bin/bash
# openclaw-logs.sh
# Follow logs for all services or a specific service
# Usage: openclaw-logs.sh [service-name]

cd "$(dirname "$0")/.."

# Follow logs for all services (or specific service if provided)
docker-compose -f docker/docker-compose.yml logs -f "$@"
