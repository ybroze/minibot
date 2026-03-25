#!/bin/bash
# minibot-logs.sh
# Follow logs for all services or a specific service
# Usage: minibot-logs.sh [service-name]

set -euo pipefail

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    echo "Usage: $(basename "$0") [service-name]"
    echo "  Follow Docker Compose logs for all services (or a specific service)."
    exit 0
fi

COMPOSE_FILE="$(cd "$(dirname "$0")/.." && pwd)/docker/docker-compose.yml"

# Follow logs for all services (or specific service if provided)
docker compose -f "$COMPOSE_FILE" logs --tail 100 -f "$@"
