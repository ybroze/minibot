#!/bin/bash
# admin-setup.sh
# One-time machine setup for Minibot — run as an admin user before the
# minibot user exists. Installs dependencies and creates the minibot account.

set -euo pipefail

echo "=== Minibot Admin Setup ==="
echo ""
echo "This script will (as your admin user):"
echo "  1. Enable the macOS firewall"
echo "  2. Install Xcode Command Line Tools"
echo "  3. Install Homebrew"
echo "  4. Install Docker Desktop, Tailscale, and CLI debug tools"
echo "  5. Create the 'minibot' standard user account"
echo "  6. Configure 24/7 operation (prevent sleep)"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Setup cancelled."
    exit 0
fi

# ── Step 1: Enable macOS firewall ────────────────────────────────────────────
echo ""
echo "Step 1: Enabling macOS firewall..."
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
echo "✓ Firewall enabled (stealth mode)"

# ── Step 2: Install Xcode Command Line Tools ────────────────────────────────
echo ""
echo "Step 2: Installing Xcode Command Line Tools..."
if xcode-select -p &>/dev/null; then
    echo "✓ Xcode Command Line Tools already installed"
else
    xcode-select --install
    echo ""
    echo "A dialog has opened to install Xcode Command Line Tools."
    read -p "Press Enter after the installation finishes... "
    if xcode-select -p &>/dev/null; then
        echo "✓ Xcode Command Line Tools installed"
    else
        echo "Warning: Xcode tools still not detected — you may need to retry."
    fi
fi

# ── Step 3: Install Homebrew ─────────────────────────────────────────────────
echo ""
echo "Step 3: Installing Homebrew..."
if command -v brew &>/dev/null; then
    echo "✓ Homebrew already installed"
else
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo "✓ Homebrew installed"
fi

# Ensure brew is on PATH for the rest of this script
if ! command -v brew &>/dev/null; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Add to ~/.zprofile idempotently so future shells pick it up
if ! grep -q 'brew shellenv' ~/.zprofile 2>/dev/null; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    echo "✓ Added Homebrew to ~/.zprofile"
else
    echo "✓ ~/.zprofile already has Homebrew PATH"
fi

# ── Step 4: Install Docker Desktop, Tailscale, CLI tools ────────────────────
echo ""
echo "Step 4: Installing Docker Desktop, Tailscale, and CLI tools..."
brew install --cask docker
brew install --cask tailscale
brew install libpq redis mongosh
echo "✓ Docker Desktop, Tailscale, and CLI tools installed"

# ── Step 5: Create the minibot user ─────────────────────────────────────────
echo ""
echo "Step 5: Creating 'minibot' standard user account..."
if id minibot &>/dev/null; then
    echo "✓ User 'minibot' already exists"
else
    echo "You will be prompted to set a password for the minibot user."
    sudo sysadminctl -addUser minibot -fullName "Minibot" -password -
    echo "✓ User 'minibot' created (standard account)"
fi

# ── Step 6: Configure 24/7 operation ────────────────────────────────────────
echo ""
echo "Step 6: Configuring 24/7 operation (preventing sleep)..."
sudo pmset -a sleep 0 displaysleep 0 disksleep 0
echo "✓ Sleep disabled (sleep=0, displaysleep=0, disksleep=0)"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "=== Admin Setup Complete! ==="
echo ""
echo "Manual steps remaining (cannot be scripted):"
echo "  • Open Docker Desktop and accept the license agreement:"
echo "      open -a Docker"
echo "  • Open Tailscale and log in to your tailnet"
echo "  • Enable FileVault: System Settings > Privacy & Security > FileVault"
echo "    (save the recovery key in a password manager)"
echo "  • Enable Advanced Data Protection: System Settings > Apple ID >"
echo "    iCloud > Advanced Data Protection"
echo "  • In Docker Desktop, enable 'Start Docker Desktop when you sign in'"
echo "    (do this for both the admin user and later for the minibot user)"
echo ""
echo "Next: Log in as the 'minibot' user and run install.sh"
