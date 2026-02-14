#!/bin/bash
# health-check.sh
# Check the health of Minibot services

set -euo pipefail

cd ~/minibot

echo "=== Minibot Health Check ==="
echo ""

# Check keychain secrets
echo "Keychain Secrets:"
for key in POSTGRES_PASSWORD REDIS_PASSWORD; do
    if ~/minibot/bin/minibot-secrets.sh get "$key" &>/dev/null; then
        echo "✓ $key is set"
    else
        echo "✗ $key is missing (run: minibot-secrets.sh init)"
    fi
done
echo ""

# Check Docker
echo "Docker Status:"
if command -v docker &> /dev/null; then
    docker --version
    echo "✓ Docker installed"
else
    echo "✗ Docker not found"
fi
echo ""

# Check running containers
echo "Running Containers:"
docker compose -f docker/docker-compose.yml ps || echo "  (could not query containers)"
echo ""

# Check PostgreSQL
echo "PostgreSQL:"
if docker exec minibot-postgres pg_isready -U minibot &> /dev/null; then
    echo "✓ PostgreSQL is ready"
else
    echo "✗ PostgreSQL is not responding"
fi
echo ""

# Check Redis
echo "Redis:"
REDIS_PASS=$(~/minibot/bin/minibot-secrets.sh get REDIS_PASSWORD 2>/dev/null || echo "")
if [ -n "$REDIS_PASS" ] && docker exec minibot-redis redis-cli -a "$REDIS_PASS" ping &> /dev/null; then
    echo "✓ Redis is responding (authenticated)"
elif docker exec minibot-redis redis-cli ping &> /dev/null; then
    echo "⚠ Redis is responding but WITHOUT authentication"
else
    echo "✗ Redis is not responding"
fi
echo ""

# Check disk space
echo "Disk Usage (~/minibot):"
du -sh ~/minibot/data/* 2>/dev/null || echo "  (no data yet)"
echo ""

# Component versions
echo "Component Versions:"
echo "  Docker:         $(docker --version 2>/dev/null || echo 'not installed')"
echo "  Docker Compose: $(docker compose version 2>/dev/null || echo 'not installed')"
pg_image=$(docker inspect minibot-postgres --format='{{.Config.Image}}' 2>/dev/null || echo "not running")
echo "  PostgreSQL:     $pg_image"
redis_image=$(docker inspect minibot-redis --format='{{.Config.Image}}' 2>/dev/null || echo "not running")
echo "  Redis:          $redis_image"
echo ""

# Check logs
echo "Recent Errors in Logs:"
if [ -d ~/minibot/data/logs ]; then
    find ~/minibot/data/logs -name "*.log" -exec grep -li "error" {} \; 2>/dev/null | head -5 || true
    # If no output above, no errors were found
else
    echo "  (no logs directory)"
fi
echo ""

# Check LaunchAgent
PLIST_PATH="$HOME/Library/LaunchAgents/com.minibot.gateway.plist"
echo "LaunchAgent (24/7 Operation):"
if [ -f "$PLIST_PATH" ]; then
    echo "✓ Plist installed at: $PLIST_PATH"
    if launchctl list 2>/dev/null | grep -q "com.minibot.gateway"; then
        echo "✓ LaunchAgent is loaded"
    else
        echo "⚠ Plist exists but LaunchAgent is not loaded (run: launchctl load \"$PLIST_PATH\")"
    fi
else
    echo "  LaunchAgent not installed (optional — run install-launchagent.sh for 24/7 operation)"
fi
echo ""

echo "=== Health Check Complete ==="
