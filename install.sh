#!/bin/bash
# install.sh
# Quick installer for Minibot environment
# Run this as the minibot user

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Minibot Environment Installer ==="
echo ""
echo "This script will:"
echo "  1. Create the ~/minibot directory structure"
echo "  2. Copy all scripts to the correct locations"
echo "  3. Set up your shell environment"
echo "  4. Make all scripts executable"
echo "  5. Store secrets in the macOS Keychain"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "Step 1: Creating directory structure..."
bash "$SCRIPT_DIR/setup-minibot-dirs.sh"

echo ""
echo "Step 2: Copying scripts..."
cp -r "$SCRIPT_DIR/bin"/* ~/minibot/bin/
cp -r "$SCRIPT_DIR/docker"/* ~/minibot/docker/
cp -r "$SCRIPT_DIR/scripts"/* ~/minibot/scripts/

# Copy documentation
if [ -d "$SCRIPT_DIR/docs" ]; then
    cp -r "$SCRIPT_DIR/docs"/* ~/minibot/docs/ 2>/dev/null || true
fi

# Copy config templates (won't overwrite existing files)
if [ -d "$SCRIPT_DIR/config" ]; then
    cp -rn "$SCRIPT_DIR/config"/* ~/minibot/config/ 2>/dev/null || true
fi

echo ""
echo "Step 3: Making scripts executable..."
chmod +x ~/minibot/bin/*.sh
chmod +x ~/minibot/scripts/*.sh

echo ""
echo "Step 3b: Setting file permissions..."
chmod 700 ~/minibot/data

echo ""
echo "Step 4: Updating .gitignore..."
cp "$SCRIPT_DIR/gitignore-template" ~/minibot/.gitignore

echo ""
echo "Step 5: Setting up shell environment..."
if ! grep -q "MINIBOT_HOME" ~/.zshrc 2>/dev/null; then
    echo "" >> ~/.zshrc  # ensure leading newline
    cat "$SCRIPT_DIR/zshrc-additions.sh" >> ~/.zshrc
    echo "✓ Added to ~/.zshrc"
else
    echo "✓ ~/.zshrc already configured"
fi

echo ""
echo "Step 6: Setting up secrets in macOS Keychain..."
~/minibot/bin/minibot-secrets.sh init

echo ""
echo "=== Installation Complete! ==="
echo ""
echo "Next steps:"
echo "  1. Source your shell config: source ~/.zshrc"
echo "  2. Install Docker Desktop:   brew install --cask docker"
echo "  3. Start services:           mb-start"
echo ""
echo "Manage secrets anytime with: mb-secrets"
echo ""
echo "For detailed instructions, see README.md"
