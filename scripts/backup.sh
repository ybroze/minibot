#!/bin/bash
# backup.sh
# Backup Minibot data and configuration

set -euo pipefail

# Safety: validate that the source directories exist before we stop services.
for required_dir in ~/minibot/data ~/minibot/docker; do
    if [ ! -d "$required_dir" ]; then
        echo "ERROR: source directory not found: $required_dir" >&2
        echo "Nothing to back up — aborting without stopping services." >&2
        exit 1
    fi
done

BACKUP_ROOT="$HOME/minibot-backups"
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"

echo "Creating backup at: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# Safety: if interrupted after stopping services, ensure we attempt a restart.
SERVICES_STOPPED=false
cleanup_on_interrupt() {
    echo ""
    echo "Interrupted — cleaning up..." >&2
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

# Backup data
echo "Backing up data..."
cp -rp ~/minibot/data "$BACKUP_DIR/"

# Backup docker configs
echo "Backing up Docker configurations..."
cp -rp ~/minibot/docker "$BACKUP_DIR/"

# Create backup manifest
cat > "$BACKUP_DIR/MANIFEST.txt" << EOF
Minibot Backup
Created: $(date)
Hostname: $(hostname)
User: $(whoami)

Contents:
- data/
- docker/
EOF

# Idempotency: always restart services even if the backup had issues, and
# report failure clearly so re-running the script leaves the system healthy.
echo "Restarting services..."
if ! ~/minibot/bin/minibot-start.sh; then
    echo ""
    echo "ERROR: Backup succeeded but services failed to restart!" >&2
    echo "Backup is at: $BACKUP_DIR" >&2
    echo "Run 'mb-start' manually to bring services back up." >&2
    exit 1
fi
SERVICES_STOPPED=false

echo ""
echo "✓ Backup created at: $BACKUP_DIR"
echo ""
echo "To restore: ~/minibot/scripts/restore.sh $BACKUP_DIR"
echo "Keep only the last 5-10 backups and delete older ones to save space."
