#!/bin/bash
# setup-minibot-dirs.sh
# Run this script as the minibot user to create the directory structure

set -euo pipefail

BASE_DIR="$HOME/minibot"

echo "Creating Minibot directory structure at: $BASE_DIR"

# Create main directories
mkdir -p "$BASE_DIR"/{bin,config,data,docker,agents,lib,scripts,experiments,docs,tmp}

# Config subdirectories
mkdir -p "$BASE_DIR/config"/{agents,orchestration,environments}

# Data subdirectories
mkdir -p "$BASE_DIR/data"/{postgres,redis,logs/{agents,orchestrator,system}}

# Docker subdirectories
mkdir -p "$BASE_DIR/docker/Dockerfiles"

# Lib subdirectories
mkdir -p "$BASE_DIR/lib"/{python,node}

# Standard hidden directories
mkdir -p "$HOME/.config" "$HOME/.cache" "$HOME/.local"/{bin,lib}

# Create .gitkeep files for empty directories
find "$BASE_DIR" -type d -empty -exec touch {}/.gitkeep \;

# Set up basic .gitignore
cat > "$BASE_DIR/.gitignore" << 'EOF'
# Data & logs
data/
tmp/
*.log

# Environment files
*.env
!*.env.example

# IDE
.vscode/
.idea/

# OS
.DS_Store
EOF

# Set restrictive permissions on sensitive directories
chmod 700 "$BASE_DIR/config"
chmod 700 "$BASE_DIR/data"
chmod 700 "$BASE_DIR/tmp"

echo "✓ Directory structure created at: $BASE_DIR"
echo ""
echo "Next steps:"
echo "  1. Copy the bin/ scripts to $BASE_DIR/bin/"
echo "  2. Copy docker/ files to $BASE_DIR/docker/"
echo "  3. Copy scripts/ files to $BASE_DIR/scripts/"
echo "  4. Make scripts executable: chmod +x $BASE_DIR/bin/*.sh $BASE_DIR/scripts/*.sh"
