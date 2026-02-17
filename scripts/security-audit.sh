#!/bin/bash
# security-audit.sh
# Check the security posture of the Minibot environment.
# Run this periodically (weekly recommended).

set -euo pipefail

PASS=0
WARN=0
FAIL=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
warn() { echo "  ⚠ $1"; WARN=$((WARN + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

echo "=== Minibot Security Audit ==="
echo ""

# --- 1. Keychain secrets ---------------------------------------------------
echo "Keychain Secrets:"

for key in POSTGRES_PASSWORD REDIS_PASSWORD ANTHROPIC_API_KEY TELEGRAM_BOT_TOKEN OPENCLAW_GATEWAY_TOKEN; do
    val=$(~/minibot/bin/minibot-secrets.sh get "$key" 2>/dev/null || true)
    if [ -z "$val" ]; then
        fail "$key is not set in the keychain"
    elif [ "$val" = "changeme" ] || [ "$val" = "password" ] || [ ${#val} -lt 12 ]; then
        warn "$key is set but looks weak (default or < 12 chars)"
    else
        pass "$key is set (${#val} chars)"
    fi
done
echo ""

# --- 2. Docker status ------------------------------------------------------
echo "Docker:"

if ! docker info &>/dev/null; then
    fail "Docker is not running"
else
    pass "Docker is running"
fi
echo ""

# --- 3. Port binding -------------------------------------------------------
echo "Port Binding:"

compose_file=~/minibot/docker/docker-compose.yml
if [ -f "$compose_file" ]; then
    # Check for any port binding that isn't localhost
    if grep -E '^\s*-\s*"[0-9]+:[0-9]+"' "$compose_file" | grep -v '127\.0\.0\.1' &>/dev/null; then
        fail "docker-compose.yml has ports not bound to 127.0.0.1"
        grep -n -E '^\s*-\s*"[0-9]+:[0-9]+"' "$compose_file" | grep -v '127\.0\.0\.1' | while read -r line; do
            echo "       $line"
        done
    else
        pass "All ports bound to 127.0.0.1"
    fi
else
    warn "docker-compose.yml not found at expected path"
fi
echo ""

# --- 4. Redis authentication -----------------------------------------------
echo "Redis Authentication:"

if docker exec minibot-redis redis-cli ping 2>/dev/null | grep -q PONG; then
    fail "Redis accepts unauthenticated connections (no --requirepass)"
elif docker exec minibot-redis redis-cli --no-auth-warning -a "$(~/minibot/bin/minibot-secrets.sh get REDIS_PASSWORD 2>/dev/null || echo '')" ping 2>/dev/null | grep -q PONG; then
    pass "Redis requires authentication"
else
    warn "Redis is not running or could not verify auth"
fi
echo ""

# --- 5. File permissions ---------------------------------------------------
echo "File Permissions:"

for dir in ~/minibot/data; do
    if [ -d "$dir" ]; then
        perms=$(stat -f "%Lp" "$dir" 2>/dev/null || stat -c "%a" "$dir" 2>/dev/null)
        if [ "$perms" = "700" ]; then
            pass "$dir is 700 (owner only)"
        else
            warn "$dir is $perms (should be 700)"
        fi
    fi
done
echo ""

# --- 5b. Umask --------------------------------------------------------------
echo "Umask:"

current_umask=$(umask)
if [ "$current_umask" = "0077" ] || [ "$current_umask" = "077" ]; then
    pass "umask is $current_umask (owner-only default)"
else
    warn "umask is $current_umask (should be 077 for owner-only file creation)"
fi
echo ""

# --- 6. macOS Firewall -----------------------------------------------------
echo "macOS Firewall:"

fw_state=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "unknown")
if echo "$fw_state" | grep -qi "enabled"; then
    pass "macOS firewall is enabled"
else
    warn "macOS firewall may be disabled"
fi
echo ""

# --- 7. FileVault ----------------------------------------------------------
echo "FileVault:"

fv_status=$(fdesetup status 2>/dev/null || echo "unknown")
if echo "$fv_status" | grep -qi "on"; then
    pass "FileVault is enabled"
else
    warn "FileVault may not be enabled — data at rest is not encrypted"
fi
echo ""

# --- 8. Stray .env files ---------------------------------------------------
echo "Stray .env Files:"

env_files=$(find ~/minibot -name "*.env" ! -name "*.env.example" 2>/dev/null || true)
if [ -n "$env_files" ]; then
    warn "Found .env files (secrets should be in Keychain, not on disk):"
    echo "$env_files" | while read -r f; do echo "       $f"; done
else
    pass "No .env files found"
fi
echo ""

# --- 9. Version info -------------------------------------------------------
echo "Component Versions:"

echo "  Docker:          $(docker --version 2>/dev/null || echo 'not installed')"
echo "  Docker Compose:  $(docker compose version 2>/dev/null || echo 'not installed')"

pg_image=$(docker inspect minibot-postgres --format='{{.Config.Image}}' 2>/dev/null || echo "not running")
echo "  PostgreSQL:      $pg_image"

redis_image=$(docker inspect minibot-redis --format='{{.Config.Image}}' 2>/dev/null || echo "not running")
echo "  Redis:           $redis_image"

oc_image=$(docker inspect minibot-openclaw --format='{{.Config.Image}}' 2>/dev/null || echo "not running")
echo "  OpenClaw:        $oc_image"
echo ""

# --- Summary ----------------------------------------------------------------
echo "=== Audit Summary ==="
echo "  Passed:   $PASS"
echo "  Warnings: $WARN"
echo "  Failed:   $FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo "Action required: fix the failures above before running services."
    exit 1
elif [ "$WARN" -gt 0 ]; then
    echo "Review the warnings above. No critical issues found."
    exit 0
else
    echo "All checks passed."
    exit 0
fi
