#!/bin/bash
# verify-install.sh
# Run as the minibot user after completing all setup steps.
# Verifies Docker services, Ollama, user isolation, and API connectivity.

set -euo pipefail

PASS=0
WARN=0
FAIL=0

pass() { echo "✓ $1"; PASS=$((PASS + 1)); }
warn() { echo "⚠ $1"; WARN=$((WARN + 1)); }
fail() { echo "✗ $1"; FAIL=$((FAIL + 1)); }

echo "=== Minibot Installation Verification ==="
echo ""

# ── Docker Services ──────────────────────────────────────────────────────────

echo "Docker Services:"
if docker info &>/dev/null; then
    pass "Docker is running"
else
    fail "Docker is not running"
fi

for svc in minibot-postgres minibot-redis minibot-mongo minibot-openclaw; do
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${svc}$"; then
        pass "$svc is running"
    else
        fail "$svc is not running"
    fi
done
echo ""

# ── Ollama (running as ollama user) ─────────────────────────────────────────

echo "Ollama (managed by 'ollama' user):"
if curl -s --max-time 5 http://127.0.0.1:11434/ &>/dev/null; then
    pass "Ollama is running on port 11434"
else
    fail "Ollama is not responding on port 11434"
fi

if curl -s --max-time 5 http://127.0.0.1:11434/api/tags 2>/dev/null | grep -q "llama3.1"; then
    pass "llama3.1:8b model is available"
else
    warn "llama3.1:8b model not found (log in as 'ollama' and run: ollama pull llama3.1:8b)"
fi

ollama_user=$(ps aux | grep "[o]llama serve" | awk '{print $1}' | head -1)
if [ "$ollama_user" = "ollama" ]; then
    pass "Ollama is running as 'ollama' user"
elif [ -n "$ollama_user" ]; then
    warn "Ollama is running as '$ollama_user' (expected 'ollama')"
else
    warn "Could not determine which user owns the Ollama process"
fi
echo ""

# ── Ollama API Test ──────────────────────────────────────────────────────────

echo "Ollama API:"
response=$(curl -s --max-time 30 http://127.0.0.1:11434/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model":"llama3.1:8b","messages":[{"role":"user","content":"Reply with the single word OK"}]}' 2>/dev/null || echo "")

if echo "$response" | grep -q '"content"'; then
    pass "Ollama API returned a response"
else
    fail "Ollama API did not return a valid response"
fi
echo ""

# ── Docker-to-Ollama Connectivity ────────────────────────────────────────────

echo "Docker-to-Ollama:"
if docker exec minibot-openclaw sh -c "curl -s --max-time 5 http://host.docker.internal:11434/" &>/dev/null 2>&1; then
    pass "Containers can reach Ollama via host.docker.internal:11434"
else
    warn "Containers cannot reach host.docker.internal:11434 (check Docker Desktop settings)"
fi
echo ""

# ── Secrets ──────────────────────────────────────────────────────────────────

echo "Secrets:"
for key in POSTGRES_PASSWORD REDIS_PASSWORD MONGO_PASSWORD OPENCLAW_GATEWAY_PASSWORD; do
    if ~/minibot/bin/minibot-secrets.sh get "$key" &>/dev/null; then
        pass "$key is set in Keychain"
    else
        fail "$key is missing from Keychain"
    fi
done
echo ""

# ── User Isolation ───────────────────────────────────────────────────────────

echo "User Isolation:"
if [ "$(whoami)" = "minibot" ]; then
    pass "Running as minibot user"
else
    warn "Running as $(whoami) (expected minibot)"
fi

if ! ls /Users/ollama/ &>/dev/null 2>&1; then
    pass "minibot cannot read ollama's home directory"
else
    fail "minibot CAN read ollama's home directory (permissions too open)"
fi

if ! ls /Users/ollama/.ollama/ &>/dev/null 2>&1; then
    pass "minibot cannot read ollama's model files"
else
    fail "minibot CAN read ollama's model files"
fi
echo ""

# ── LaunchAgents ─────────────────────────────────────────────────────────────

echo "LaunchAgents (minibot user):"
if launchctl list com.minibot.gateway &>/dev/null; then
    pass "com.minibot.gateway is loaded"
else
    fail "com.minibot.gateway is not loaded"
fi

if launchctl list com.minibot.caffeinate &>/dev/null; then
    pass "com.minibot.caffeinate is loaded"
else
    fail "com.minibot.caffeinate is not loaded"
fi
echo ""

# ── Summary ──────────────────────────────────────────────────────────────────

echo "=== Results ==="
echo "  Passed:   $PASS"
echo "  Warnings: $WARN"
echo "  Failed:   $FAIL"
echo ""

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
    echo "All checks passed."
elif [ "$FAIL" -eq 0 ]; then
    echo "All critical checks passed. Review warnings above."
else
    echo "Some checks failed. Review output above."
    exit 1
fi
