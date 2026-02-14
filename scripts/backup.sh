#!/bin/bash
# backup.sh
# Backup Minibot data and configuration

set -euo pipefail

BACKUP_ROOT="$HOME/minibot-backups"
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"

echo "Creating backup at: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Stop services
echo "Stopping services..."
~/minibot/bin/minibot-stop.sh

# Backup data
echo "Backing up data..."
cp -rp ~/minibot/data "$BACKUP_DIR/"

# Backup config
echo "Backing up configuration..."
cp -rp ~/minibot/config "$BACKUP_DIR/"

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
- config/
- docker/
EOF

# Restart services
echo "Restarting services..."
~/minibot/bin/minibot-start.sh

echo ""
echo "✓ Backup created at: $BACKUP_DIR"
echo ""
echo "To restore, copy the backed up directories back to ~/minibot/"
echo "Keep only the last 5-10 backups and delete older ones to save space."
