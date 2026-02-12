#!/bin/bash
# backup.sh
# Backup OpenClaw data and configuration

set -e

BACKUP_ROOT="$HOME/openclaw-backups"
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"

echo "Creating backup at: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Stop services
echo "Stopping services..."
~/openclaw/bin/openclaw-stop.sh

# Backup data
echo "Backing up data..."
cp -r ~/openclaw/data "$BACKUP_DIR/"

# Backup config
echo "Backing up configuration..."
cp -r ~/openclaw/config "$BACKUP_DIR/"

# Backup docker configs
echo "Backing up Docker configurations..."
cp -r ~/openclaw/docker "$BACKUP_DIR/"

# Create backup manifest
cat > "$BACKUP_DIR/MANIFEST.txt" << EOF
OpenClaw Backup
Created: $(date)
Hostname: $(hostname)
User: $(whoami)

Contents:
- data/
- config/
- docker/
EOF

# Restart services
echo "Restarting services..."
~/openclaw/bin/openclaw-start.sh

echo ""
echo "✓ Backup created at: $BACKUP_DIR"
echo ""
echo "To restore, copy the backed up directories back to ~/openclaw/"
echo "Keep only the last 5-10 backups and delete older ones to save space."
