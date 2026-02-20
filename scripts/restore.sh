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

if [ ! -d "$BACKUP_DIR/data" ] && [ ! -d "$BACKUP_DIR/docker" ]; then
    echo "Error: Backup directory contains neither data/ nor docker/." >&2
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

# Safety: if interrupted after stopping services, ensure we attempt a restart.
SERVICES_STOPPED=false
cleanup_on_interrupt() {
    echo ""
    echo "Interrupted — cleaning up..." >&2
    echo "NOTE: Rollback dirs (data.bak, docker.bak) preserved for manual recovery." >&2
    if $SERVICES_STOPPED; then
        echo "Attempting to restart services..." >&2
        ~/minibot/bin/minibot-start.sh || echo "WARNING: services may still be stopped." >&2
    fi
    exit 130
}
trap cleanup_on_interrupt SIGINT SIGTERM

# Stop services
echo "Stopping services..."
~/minibot/bin/minibot-stop.sh
SERVICES_STOPPED=true

# Safety: warn if stale .bak dirs exist from a previous failed restore.
for stale in ~/minibot/data.bak ~/minibot/docker.bak; do
    if [ -d "$stale" ]; then
        echo "WARNING: removing stale rollback dir from a previous restore: $stale" >&2
    fi
done

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

# Restart services (check for failure so we don't falsely claim success)
echo "Restarting services..."
if ! ~/minibot/bin/minibot-start.sh; then
    echo ""
    echo "ERROR: Restore completed but services failed to restart!" >&2
    echo "Run 'mb-start' manually to bring services back up." >&2
    exit 1
fi
SERVICES_STOPPED=false

echo ""
echo "✓ Restore completed successfully."
