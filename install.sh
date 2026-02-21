#!/bin/bash
# install.sh
# Quick installer for Minibot environment
# Run this as the minibot user

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Tracking variables for completion recap
_step_dirs="pending"
_step_scripts="pending"
_step_shell="pending"
_step_secrets="pending"
_step_cli="pending"
_step_openclaw="pending"
_step_launchagent="pending"
_step_hardening="pending"

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
echo "  8. (Optional) Harden this account for dedicated use"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "Step 1: Creating directory structure..."
bash "$SCRIPT_DIR/setup-minibot-dirs.sh"
_step_dirs="done"

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
_step_scripts="done"

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
_step_shell="done"

echo ""
echo "Step 4: Setting up secrets in macOS Keychain..."
_all_secrets_exist=true
while IFS= read -r _key; do
    if ! ~/minibot/bin/minibot-secrets.sh get "$_key" &>/dev/null; then
        _all_secrets_exist=false
        break
    fi
done < <(~/minibot/bin/minibot-secrets.sh keys)
if $_all_secrets_exist; then
    echo "✓ All required secrets already exist in keychain — skipping init."
    _step_secrets="skipped (already present)"
else
    ~/minibot/bin/minibot-secrets.sh init
    _step_secrets="done"
fi

echo ""
echo "Step 5: Installing CLI debugging tools..."
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
if [ -w "$BREW_PREFIX/bin" ]; then
    brew install libpq redis mongosh
    echo "✓ Installed psql, redis-cli, mongosh"
    _step_cli="done"
else
    if dseditgroup -o checkmember -m "$(whoami)" admin &>/dev/null; then
        echo "Admin privileges required for Homebrew packages."
        echo "Attempting with sudo..."
        if sudo -u "$(stat -f '%Su' "$BREW_PREFIX/bin")" brew install libpq redis mongosh; then
            echo "✓ Installed psql, redis-cli, mongosh"
            _step_cli="done"
        else
            echo "Skipped — install manually as admin: brew install libpq redis mongosh"
            _step_cli="skipped (install failed)"
        fi
    else
        echo "Skipped — standard user cannot install Homebrew packages."
        echo "Install as admin: brew install libpq redis mongosh"
        _step_cli="skipped (standard user)"
    fi
fi

echo ""
echo "Step 6: Building OpenClaw Docker image..."
if docker image inspect openclaw:local &>/dev/null; then
    _built_at=$(docker image inspect openclaw:local --format='{{.Created}}' 2>/dev/null || echo "unknown")
    echo "openclaw:local already exists (built: $_built_at)"
    echo -n "Rebuild? (y/N): "
    read -r _rebuild
    if [ "$_rebuild" = "y" ] || [ "$_rebuild" = "Y" ]; then
        ~/minibot/scripts/build-openclaw.sh
        _step_openclaw="done (rebuilt)"
    else
        echo "Skipped rebuild."
        _step_openclaw="skipped (already exists)"
    fi
else
    echo "(This clones the OpenClaw source and builds the image — may take a few minutes.)"
    ~/minibot/scripts/build-openclaw.sh
    _step_openclaw="done"
fi

echo ""
echo "Step 7: Installing LaunchAgent for 24/7 operation..."
~/minibot/scripts/install-launchagent.sh
_step_launchagent="done"

echo ""
echo "Step 8: Account hardening (optional)..."
echo ""
echo "This disables App Store auto-updates to minimize background noise"
echo "on this dedicated account."
echo ""
read -p "Harden this account for dedicated use? (yes/no): " harden

if [ "$harden" = "yes" ]; then
    defaults write com.apple.commerce AutoUpdate -bool false
    echo "✓ Disabled App Store auto-updates"
    _step_hardening="done"
else
    echo "Skipped account hardening."
    _step_hardening="skipped"
fi

echo ""
echo "=== Installation Complete! ==="
echo ""
_recap() {
    local label="$1" status="$2"
    if [[ "$status" == done* ]]; then
        echo "  ✓ $label"
    elif [[ "$status" == skipped* ]]; then
        echo "  - $label: $status"
    else
        echo "  ✗ $label: $status"
    fi
}
_recap "Directory structure" "$_step_dirs"
_recap "Scripts & permissions" "$_step_scripts"
_recap "Shell environment" "$_step_shell"
_recap "Keychain secrets" "$_step_secrets"
_recap "CLI tools" "$_step_cli"
_recap "OpenClaw image" "$_step_openclaw"
_recap "LaunchAgent" "$_step_launchagent"
_recap "Account hardening" "$_step_hardening"
echo ""
echo "Next steps:"
echo "  1. Source your shell config: source ~/.zshrc"
echo "  2. Start services:           mb-start"
echo ""
echo "Manage secrets anytime with: mb-secrets"
echo ""
echo "Remaining manual steps (require admin/sudo):"
echo "  • Disable Spotlight on data dir: sudo mdutil -i off ~/minibot/data"
echo "  • Disable iCloud, Siri, Location Services (System Settings — GUI only)"
echo ""
echo "For detailed instructions, see README.md"
