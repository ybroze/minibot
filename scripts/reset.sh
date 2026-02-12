#!/bin/bash
# reset.sh
# Nuclear option: completely reset OpenClaw environment
# WARNING: This deletes ALL data and containers!

set -e

echo "=== OpenClaw Environment Reset ==="
echo ""
echo "WARNING: This will:"
echo "  - Stop all services"
echo "  - Delete all data (PostgreSQL, Redis, logs)"
echo "  - Remove all Docker containers and volumes"
echo ""
read -p "Are you ABSOLUTELY SURE? (type 'reset' to confirm): " confirm

if [ "$confirm" != "reset" ]; then
    echo "Reset cancelled."
    exit 0
fi

echo ""
echo "Stopping services..."
~/openclaw/bin/openclaw-stop.sh

echo "Removing containers and volumes..."
docker-compose -f ~/openclaw/docker/docker-compose.yml down -v

echo "Deleting data directories..."
rm -rf ~/openclaw/data/*

echo "Recreating data structure..."
mkdir -p ~/openclaw/data/{postgres,redis,logs/{agents,orchestrator,system}}

echo ""
echo "✓ Environment reset complete."
echo ""
echo "To start fresh, run: ~/openclaw/bin/openclaw-start.sh"
