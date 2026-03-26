#!/bin/bash
# setup-minibot-dirs.sh
# Run this script as the minibot user to create the directory structure

set -euo pipefail

BASE_DIR="$HOME/minibot"

echo "Creating Minibot directory structure at: $BASE_DIR"

# Create main directories
mkdir -p "$BASE_DIR"/{bin,data,docker,scripts,docs,vendor}

# Data subdirectories
mkdir -p "$BASE_DIR/data"/{postgres,redis,mongo,openclaw,logs/system}

# Standard hidden directories
mkdir -p "$HOME/.config" "$HOME/.cache" "$HOME/.local"/{bin,lib}

# Idempotency: only create .gitignore if it doesn't already exist, so that
# user customizations are preserved across re-runs of this script.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ ! -f "$BASE_DIR/.gitignore" ]; then
    if [ -f "$SCRIPT_DIR/gitignore-template" ]; then
        cp "$SCRIPT_DIR/gitignore-template" "$BASE_DIR/.gitignore"
    else
        cat > "$BASE_DIR/.gitignore" << 'EOF'
data/
*.log
*.env
!*.env.example
.DS_Store
EOF
    fi
fi

# Set restrictive permissions on sensitive directories
chmod 700 "$BASE_DIR/data"

echo "✓ Directory structure created at: $BASE_DIR"
