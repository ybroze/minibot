#!/bin/bash
# reset.sh
# Nuclear option: completely reset Minibot environment
# WARNING: This deletes ALL data and containers!

set -e

echo "=== Minibot Environment Reset ==="
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
~/minibot/bin/minibot-stop.sh

echo "Removing containers and volumes..."
docker-compose -f ~/minibot/docker/docker-compose.yml down -v

echo "Deleting data directories..."
rm -rf ~/minibot/data/*

echo "Recreating data structure..."
mkdir -p ~/minibot/data/{postgres,redis,logs/{agents,orchestrator,system}}

echo ""
echo "✓ Environment reset complete."
echo ""
echo "To start fresh, run: ~/minibot/bin/minibot-start.sh"
