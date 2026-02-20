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
echo "  4. Store secrets in the macOS Keychain"
echo "  5. Install CLI debugging tools (may require admin privileges)"
echo "  6. Build the OpenClaw Docker image"
echo "  7. Install LaunchAgent for 24/7 operation"
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

echo ""
echo "Step 2b: Setting file permissions..."
chmod +x ~/minibot/bin/*.sh ~/minibot/scripts/*.sh
chmod 700 ~/minibot/data

echo ""
echo "Step 3: Setting up shell environment..."
# Idempotency: instead of inlining the additions into .zshrc (which makes
# updates impossible on re-run), copy the file and source it.  The guard
# ensures we only append the source line once; the cp always brings the
# latest version of the additions file.
cp "$SCRIPT_DIR/zshrc-additions.sh" ~/minibot/zshrc-additions.sh
if ! grep -q "source ~/minibot/zshrc-additions.sh" ~/.zshrc 2>/dev/null; then
    echo "" >> ~/.zshrc  # ensure leading newline
    echo "source ~/minibot/zshrc-additions.sh" >> ~/.zshrc
    echo "✓ Added source line to ~/.zshrc"
else
    echo "✓ ~/.zshrc already configured (additions file updated in place)"
fi

echo ""
echo "Step 4: Setting up secrets in macOS Keychain..."
~/minibot/bin/minibot-secrets.sh init

echo ""
echo "Step 5: Installing CLI debugging tools..."
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
if [ -w "$BREW_PREFIX/bin" ]; then
    brew install libpq redis mongosh
    echo "✓ Installed psql, redis-cli, mongosh"
else
    if dseditgroup -o checkmember -m "$(whoami)" admin &>/dev/null; then
        echo "Admin privileges required for Homebrew packages."
        echo "Attempting with sudo..."
        if sudo -u "$(stat -f '%Su' "$BREW_PREFIX/bin")" brew install libpq redis mongosh; then
            echo "✓ Installed psql, redis-cli, mongosh"
        else
            echo "Skipped — install manually as admin: brew install libpq redis mongosh"
        fi
    else
        echo "Skipped — standard user cannot install Homebrew packages."
        echo "Install as admin: brew install libpq redis mongosh"
    fi
fi

echo ""
echo "Step 6: Building OpenClaw Docker image..."
echo "(This clones the OpenClaw source and builds the image — may take a few minutes.)"
~/minibot/scripts/build-openclaw.sh

echo ""
echo "Step 7: Installing LaunchAgent for 24/7 operation..."
~/minibot/scripts/install-launchagent.sh

echo ""
echo "=== Installation Complete! ==="
echo ""
echo "Next steps:"
echo "  1. Source your shell config: source ~/.zshrc"
echo "  2. Start services:           mb-start"
echo ""
echo "Manage secrets anytime with: mb-secrets"
echo ""
echo "For detailed instructions, see README.md"
