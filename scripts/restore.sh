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

# Idempotency: use move-then-copy with rollback so an interrupted restore
# does not leave us with deleted data and no replacement.
if [ -d "$BACKUP_DIR/data" ]; then
    echo "Restoring data..."
    rm -rf ~/minibot/data.bak
    if [ -d ~/minibot/data ]; then
        mv ~/minibot/data ~/minibot/data.bak
    fi
    if cp -rp "$BACKUP_DIR/data" ~/minibot/; then
        rm -rf ~/minibot/data.bak
    else
        echo "ERROR: data restore failed — rolling back." >&2
        rm -rf ~/minibot/data
        if [ -d ~/minibot/data.bak ]; then
            mv ~/minibot/data.bak ~/minibot/data
        fi
        exit 1
    fi
fi

# Idempotency: same move-then-copy pattern for docker configs.
if [ -d "$BACKUP_DIR/docker" ]; then
    echo "Restoring Docker configurations..."
    rm -rf ~/minibot/docker.bak
    if [ -d ~/minibot/docker ]; then
        mv ~/minibot/docker ~/minibot/docker.bak
    fi
    if cp -rp "$BACKUP_DIR/docker" ~/minibot/; then
        rm -rf ~/minibot/docker.bak
    else
        echo "ERROR: docker config restore failed — rolling back." >&2
        rm -rf ~/minibot/docker
        if [ -d ~/minibot/docker.bak ]; then
            mv ~/minibot/docker.bak ~/minibot/docker
        fi
        exit 1
    fi
fi

# Re-apply restrictive permissions on sensitive directories
echo "Restoring directory permissions..."
chmod 700 ~/minibot/data 2>/dev/null || true

# Restart services
echo "Restarting services..."
~/minibot/bin/minibot-start.sh

echo ""
echo "✓ Restore completed successfully."
