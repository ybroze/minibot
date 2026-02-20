#!/bin/bash
# minibot-logs.sh
# Follow logs for all services or a specific service
# Usage: minibot-logs.sh [service-name]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

# Load secrets so docker compose can parse the compose file
eval "$("$SCRIPT_DIR/minibot-secrets.sh" export)"

# Follow logs for all services (or specific service if provided)
docker compose -f docker/docker-compose.yml logs -f "$@"
