#!/bin/bash
# minibot-logs.sh
# Follow logs for all services or a specific service
# Usage: minibot-logs.sh [service-name]

set -euo pipefail

cd "$(dirname "$0")/.."

# Follow logs for all services (or specific service if provided)
docker compose -f docker/docker-compose.yml logs -f "$@"
