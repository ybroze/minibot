#!/bin/bash
# health-check.sh
# Check the health of Minibot services

set -euo pipefail

COMPOSE_FILE="$HOME/minibot/docker/docker-compose.yml"

# Load all secrets once up front
eval "$(~/minibot/bin/minibot-secrets.sh export)"

FAILURES=0

echo "=== Minibot Health Check ==="
echo ""

# Check keychain secrets
echo "Keychain Secrets:"
while IFS= read -r key; do
    if [ -n "${!key:-}" ]; then
        echo "✓ $key is set"
    else
        echo "✗ $key is missing (run: mb-secrets init)"
        FAILURES=$((FAILURES + 1))
    fi
done < <(~/minibot/bin/minibot-secrets.sh keys)
echo ""

# Check Docker
echo "Docker Status:"
if command -v docker &> /dev/null; then
    docker --version
    echo "✓ Docker installed"
else
    echo "✗ Docker not found"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Check openclaw:local image
echo "OpenClaw Image:"
if docker image inspect openclaw:local &>/dev/null; then
    built_at=$(docker image inspect openclaw:local --format='{{.Created}}' 2>/dev/null || echo "unknown")
    echo "✓ openclaw:local exists (built: $built_at)"
else
    echo "✗ openclaw:local not found (run: mb-build)"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Check running containers
echo "Running Containers:"
docker compose -f "$COMPOSE_FILE" ps || echo "  (could not query containers)"
echo ""

# Check PostgreSQL
echo "PostgreSQL:"
if docker exec minibot-postgres pg_isready -U minibot &> /dev/null; then
    echo "✓ PostgreSQL is ready"
else
    echo "✗ PostgreSQL is not responding"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Check Redis
echo "Redis:"
if [ -n "${REDIS_PASSWORD:-}" ] && docker exec minibot-redis redis-cli --no-auth-warning -a "$REDIS_PASSWORD" ping &> /dev/null; then
    echo "✓ Redis is responding (authenticated)"
elif docker exec minibot-redis redis-cli ping &> /dev/null; then
    echo "⚠ Redis is responding but WITHOUT authentication"
else
    echo "✗ Redis is not responding"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Check MongoDB
echo "MongoDB:"
if [ -n "${MONGO_PASSWORD:-}" ] && docker exec minibot-mongo mongosh --quiet -u minibot -p "$MONGO_PASSWORD" --authenticationDatabase admin --eval "db.runCommand({ping:1})" &> /dev/null; then
    echo "✓ MongoDB is responding (authenticated)"
elif docker exec minibot-mongo mongosh --quiet --eval "db.runCommand({ping:1})" &> /dev/null; then
    echo "⚠ MongoDB is responding but authentication status unclear"
else
    echo "✗ MongoDB is not responding"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Check OpenClaw
echo "OpenClaw:"
if docker exec minibot-openclaw node -e "process.exit(0)" &> /dev/null; then
    echo "✓ OpenClaw container is running"
    oc_image=$(docker inspect minibot-openclaw --format='{{.Config.Image}}' 2>/dev/null || echo "unknown")
    echo "  Image: $oc_image"
else
    echo "✗ OpenClaw is not running"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Check Ollama
echo "Ollama (Local LLM):"
if curl -s --max-time 5 http://127.0.0.1:11434/ &>/dev/null; then
    echo "✓ Ollama is running on port 11434"
    model_count=$(ollama list 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
    echo "  Models available: $model_count"
    if ollama list 2>/dev/null | grep -q "llama3.1:8b"; then
        echo "  ✓ llama3.1:8b is loaded"
    else
        echo "  ⚠ llama3.1:8b not found (run: ollama pull llama3.1:8b)"
    fi
else
    echo "- Ollama is not running"
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
mongo_image=$(docker inspect minibot-mongo --format='{{.Config.Image}}' 2>/dev/null || echo "not running")
echo "  MongoDB:        $mongo_image"
oc_image=$(docker inspect minibot-openclaw --format='{{.Config.Image}}' 2>/dev/null || echo "not running")
echo "  OpenClaw:       $oc_image"
echo ""

# Check LaunchAgent logs (container logs are managed by Docker's json-file driver)
echo "Recent Errors in LaunchAgent Logs:"
if [ -d ~/minibot/data/logs/system ]; then
    find ~/minibot/data/logs/system -name "*.log" -exec grep -li "error" {} \; 2>/dev/null | head -5 || true
    # If no output above, no errors were found
else
    echo "  (no LaunchAgent logs yet)"
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
        echo "⚠ Plist exists but LaunchAgent is not loaded (run: ~/minibot/scripts/install-launchagent.sh)"
    fi
else
    echo "  LaunchAgent not installed (optional — run install-launchagent.sh for 24/7 operation)"
fi
echo ""

# Check energy settings (headless operation)
echo "Energy Settings (Headless Operation):"
if pmset -g 2>/dev/null | grep -q "sleep.*0"; then
    echo "✓ System sleep is disabled"
else
    echo "⚠ System sleep may not be disabled (run: sudo pmset -a sleep 0)"
fi
if pmset -g 2>/dev/null | grep -q "autorestart.*1"; then
    echo "✓ Auto-restart after power failure is enabled"
else
    echo "⚠ Auto-restart after power failure is not enabled"
fi
if pgrep -x "caffeinate" &>/dev/null; then
    echo "✓ caffeinate is running"
else
    echo "⚠ caffeinate is not running (run: ~/minibot/scripts/install-launchagent-caffeinate.sh)"
fi
echo ""

echo "=== Health Check Complete ==="

if [ "$FAILURES" -gt 0 ]; then
    echo "$FAILURES critical check(s) failed."
    exit 1
fi
