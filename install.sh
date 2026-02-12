#!/bin/bash
# install.sh
# Quick installer for OpenClaw environment
# Run this as the openclaw user

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== OpenClaw Environment Installer ==="
echo ""
echo "This script will:"
echo "  1. Create the ~/openclaw directory structure"
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
bash "$SCRIPT_DIR/setup-openclaw-dirs.sh"

echo ""
echo "Step 2: Copying scripts..."
cp -r "$SCRIPT_DIR/bin"/* ~/openclaw/bin/
cp -r "$SCRIPT_DIR/docker"/* ~/openclaw/docker/
cp -r "$SCRIPT_DIR/scripts"/* ~/openclaw/scripts/

echo ""
echo "Step 3: Making scripts executable..."
chmod +x ~/openclaw/bin/*.sh
chmod +x ~/openclaw/scripts/*.sh

echo ""
echo "Step 4: Updating .gitignore..."
cp "$SCRIPT_DIR/gitignore-template" ~/openclaw/.gitignore

echo ""
echo "Step 5: Setting up shell environment..."
if ! grep -q "OPENCLAW_HOME" ~/.zshrc 2>/dev/null; then
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
echo "  4. Configure Docker: cd ~/openclaw/docker && cp .env.example .env"
echo "  5. Start services: oc-start"
echo ""
echo "For detailed instructions, see:"
echo "  - README.md"
echo "  - openclaw-macos-setup.md"
