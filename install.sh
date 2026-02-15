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

echo ""
echo "Step 3: Making scripts executable..."
chmod +x ~/minibot/bin/*.sh
chmod +x ~/minibot/scripts/*.sh

echo ""
echo "Step 3b: Setting file permissions..."
chmod 700 ~/minibot/data

echo ""
echo "Step 4: Updating .gitignore..."
# Idempotency: only create if missing, to preserve user customizations.
if [ ! -f ~/minibot/.gitignore ]; then
    if [ -f "$SCRIPT_DIR/gitignore-template" ]; then
        cp "$SCRIPT_DIR/gitignore-template" ~/minibot/.gitignore
    else
        cat > ~/minibot/.gitignore << 'GITIGNORE'
data/
*.log
*.env
!*.env.example
.DS_Store
GITIGNORE
    fi
else
    echo "✓ .gitignore already exists — skipping"
fi

echo ""
echo "Step 5: Setting up shell environment..."
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
echo "Step 6: Setting up secrets in macOS Keychain..."
~/minibot/bin/minibot-secrets.sh init

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
