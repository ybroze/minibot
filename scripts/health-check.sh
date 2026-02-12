#!/bin/bash
# health-check.sh
# Check the health of OpenClaw services

cd ~/openclaw

echo "=== OpenClaw Health Check ==="
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
docker-compose -f docker/docker-compose.yml ps
echo ""

# Check PostgreSQL
echo "PostgreSQL:"
if docker exec openclaw-postgres pg_isready -U openclaw &> /dev/null; then
    echo "✓ PostgreSQL is ready"
else
    echo "✗ PostgreSQL is not responding"
fi
echo ""

# Check Redis
echo "Redis:"
if docker exec openclaw-redis redis-cli ping &> /dev/null; then
    echo "✓ Redis is responding"
else
    echo "✗ Redis is not responding"
fi
echo ""

# Check disk space
echo "Disk Usage (~/openclaw):"
du -sh ~/openclaw/data/* 2>/dev/null || echo "  (no data yet)"
echo ""

# Check logs
echo "Recent Errors in Logs:"
if [ -d ~/openclaw/data/logs ]; then
    grep -i "error" ~/openclaw/data/logs/**/*.log 2>/dev/null | tail -n 5 || echo "  (none found)"
else
    echo "  (no logs directory)"
fi
echo ""

echo "=== Health Check Complete ==="
