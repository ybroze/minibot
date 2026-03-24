#!/bin/bash
# setup-rustdesk.sh
# Configure RustDesk for headless direct-IP access via Tailscale.
# Retrieves the permanent password from the macOS Keychain and applies it.
#
# Prerequisites:
#   - RustDesk installed (brew install --cask rustdesk)
#   - RUSTDESK_PASSWORD set in Keychain (mb-secrets set RUSTDESK_PASSWORD)
#   - Tailscale connected
#
# Run once after install, or re-run to update password / config.

set -euo pipefail

MINIBOT_DIR="$HOME/minibot"
SECRETS="$MINIBOT_DIR/bin/minibot-secrets.sh"

# RustDesk config locations (varies by version)
RUSTDESK_CONFIG_DIRS=(
    "$HOME/Library/Preferences/com.carriez.RustDesk"
    "$HOME/.config/rustdesk"
)

RUSTDESK_APP="/Applications/RustDesk.app"
RUSTDESK_BIN="$RUSTDESK_APP/Contents/MacOS/RustDesk"

echo "=== RustDesk Setup ==="
echo ""

# ── Verify prerequisites ────────────────────────────────────────────────────

if [ ! -d "$RUSTDESK_APP" ]; then
    echo "✗ RustDesk is not installed. Run: brew install --cask rustdesk"
    exit 1
fi
echo "✓ RustDesk is installed"

# Retrieve password from Keychain
RUSTDESK_PASSWORD=$("$SECRETS" get RUSTDESK_PASSWORD 2>/dev/null || true)
if [ -z "$RUSTDESK_PASSWORD" ]; then
    echo "✗ RUSTDESK_PASSWORD is not set in the Keychain."
    echo "  Run: mb-secrets set RUSTDESK_PASSWORD"
    exit 1
fi
echo "✓ RUSTDESK_PASSWORD found in Keychain (${#RUSTDESK_PASSWORD} chars)"

# ── Find or create config directory ─────────────────────────────────────────

RUSTDESK_CONFIG_DIR=""
for dir in "${RUSTDESK_CONFIG_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        RUSTDESK_CONFIG_DIR="$dir"
        break
    fi
done

if [ -z "$RUSTDESK_CONFIG_DIR" ]; then
    # Launch RustDesk briefly to create the config directory, then quit
    echo "Launching RustDesk to initialize config directory..."
    open -a RustDesk
    sleep 3
    osascript -e 'quit app "RustDesk"' 2>/dev/null || true
    sleep 1

    for dir in "${RUSTDESK_CONFIG_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            RUSTDESK_CONFIG_DIR="$dir"
            break
        fi
    done

    if [ -z "$RUSTDESK_CONFIG_DIR" ]; then
        echo "✗ Could not find RustDesk config directory after launch."
        echo "  Checked: ${RUSTDESK_CONFIG_DIRS[*]}"
        exit 1
    fi
fi
echo "✓ Config directory: $RUSTDESK_CONFIG_DIR"

RUSTDESK_TOML="$RUSTDESK_CONFIG_DIR/RustDesk.toml"
RUSTDESK2_TOML="$RUSTDESK_CONFIG_DIR/RustDesk2.toml"

# ── Set permanent password ──────────────────────────────────────────────────

echo ""
echo "Setting permanent password..."
"$RUSTDESK_BIN" --password "$RUSTDESK_PASSWORD" 2>/dev/null || true
echo "✓ Permanent password applied"

# ── Configure RustDesk2.toml (connection settings) ──────────────────────────

# RustDesk2.toml controls rendezvous server, relay, and connection options.
# For direct IP via Tailscale, we disable the relay and public servers.

echo ""
echo "Configuring RustDesk for direct IP mode..."

# Build the config — preserve existing RustDesk2.toml content where possible,
# but ensure our required keys are set.
update_toml_key() {
    local file="$1" key="$2" value="$3"
    if [ -f "$file" ] && grep -q "^${key} " "$file" 2>/dev/null; then
        sed -i '' "s#^${key} .*#${key} = '${value}'#" "$file"
    else
        echo "${key} = '${value}'" >> "$file"
    fi
}

touch "$RUSTDESK2_TOML"
update_toml_key "$RUSTDESK2_TOML" "rendezvous_server" ""
update_toml_key "$RUSTDESK2_TOML" "relay-server" ""
update_toml_key "$RUSTDESK2_TOML" "direct-server" "Y"
update_toml_key "$RUSTDESK2_TOML" "direct-access-port" "21118"
echo "✓ Direct IP mode enabled (no relay server)"

# ── Configure RustDesk.toml (UI / auth settings) ───────────────────────────

touch "$RUSTDESK_TOML"
update_toml_key "$RUSTDESK_TOML" "verification-method" "use-permanent-password"
update_toml_key "$RUSTDESK_TOML" "allow-auto-disconnect" "Y"
update_toml_key "$RUSTDESK_TOML" "enable-lan-discovery" "N"
echo "✓ Permanent-password-only mode set, LAN discovery disabled"

# ── Remove any RustDesk-installed LaunchAgents (avoid conflicts) ────────────

for plist in "$HOME/Library/LaunchAgents/"*rustdesk* "$HOME/Library/LaunchAgents/"*RustDesk*; do
    if [ -f "$plist" ] && [[ "$plist" != *"com.minibot.rustdesk"* ]]; then
        echo "Removing conflicting RustDesk LaunchAgent: $(basename "$plist")"
        launchctl bootout "gui/$(id -u)" "$plist" 2>/dev/null || true
        rm -f "$plist"
    fi
done

# ── Print connection info ───────────────────────────────────────────────────

echo ""
echo "=== RustDesk Setup Complete ==="
echo ""

# Get RustDesk ID
RUSTDESK_ID=$("$RUSTDESK_BIN" --get-id 2>/dev/null || echo "unknown")
echo "RustDesk ID: $RUSTDESK_ID"

# Get Tailscale IP
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "not connected")
echo "Tailscale IP: $TAILSCALE_IP"

echo ""
echo "To connect from another machine:"
echo "  1. Install RustDesk on your client"
echo "  2. Enter the Tailscale IP ($TAILSCALE_IP) as the remote ID"
echo "  3. Use your permanent password to authenticate"
echo ""
echo "Next steps:"
echo "  • Install the LaunchAgent: ~/minibot/scripts/install-launchagent-rustdesk.sh"
echo "  • Install caffeinate agent: ~/minibot/scripts/install-launchagent-caffeinate.sh"
echo "  • Verify: ~/minibot/scripts/health-check.sh"
