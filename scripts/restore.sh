#!/bin/bash
# restore.sh
# Restore Minibot from a backup

set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup-directory>"
    echo ""
    echo "Available backups:"
    ls -1 "$HOME/minibot-backups/" 2>/dev/null || echo "  (none found)"
    exit 1
fi

BACKUP_DIR="$1"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Backup directory not found: $BACKUP_DIR"
    exit 1
fi

echo "Restoring from: $BACKUP_DIR"
echo ""
echo "WARNING: This will overwrite current data and configuration!"
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

# Stop services
echo "Stopping services..."
~/minibot/bin/minibot-stop.sh

# Restore data
if [ -d "$BACKUP_DIR/data" ]; then
    echo "Restoring data..."
    rm -rf ~/minibot/data
    cp -rp "$BACKUP_DIR/data" ~/minibot/
fi

# Restore config
if [ -d "$BACKUP_DIR/config" ]; then
    echo "Restoring configuration..."
    rm -rf ~/minibot/config
    cp -rp "$BACKUP_DIR/config" ~/minibot/
fi

# Restore docker configs
if [ -d "$BACKUP_DIR/docker" ]; then
    echo "Restoring Docker configurations..."
    rm -rf ~/minibot/docker
    cp -rp "$BACKUP_DIR/docker" ~/minibot/
fi

# Re-apply restrictive permissions on sensitive directories
echo "Restoring directory permissions..."
chmod 700 ~/minibot/config 2>/dev/null || true
chmod 700 ~/minibot/data 2>/dev/null || true
chmod 700 ~/minibot/tmp 2>/dev/null || true

# Restart services
echo "Restarting services..."
~/minibot/bin/minibot-start.sh

echo ""
echo "✓ Restore completed successfully."
