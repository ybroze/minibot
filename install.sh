#!/bin/bash
# install.sh
# Quick installer for Minibot environment
# Run this as the minibot user

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Minibot Environment Installer ==="
echo ""
echo "This script will:"
echo "  1. Create the ~/minibot directory structure"
echo "  2. Copy all scripts to the correct locations"
echo "  3. Set up your shell environment"
echo "  4. Make all scripts executable"
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

echo ""
echo "Step 3: Making scripts executable..."
chmod +x ~/minibot/bin/*.sh
chmod +x ~/minibot/scripts/*.sh

echo ""
echo "Step 4: Updating .gitignore..."
cp "$SCRIPT_DIR/gitignore-template" ~/minibot/.gitignore

echo ""
echo "Step 5: Setting up shell environment..."
if ! grep -q "MINIBOT_HOME" ~/.zshrc 2>/dev/null; then
    cat "$SCRIPT_DIR/zshrc-additions.sh" >> ~/.zshrc
    echo "✓ Added to ~/.zshrc"
else
    echo "✓ ~/.zshrc already configured"
fi

echo ""
echo "=== Installation Complete! ==="
echo ""
echo "Next steps:"
echo "  1. Source your shell config: source ~/.zshrc"
echo "  2. Install Homebrew (if not already installed)"
echo "  3. Install dependencies: brew install docker docker-compose"
echo "  4. Configure Docker: cd ~/minibot/docker && cp .env.example .env"
echo "  5. Start services: mb-start"
echo ""
echo "For detailed instructions, see:"
echo "  - README.md"
echo "  - minibot-macos-setup.md"
