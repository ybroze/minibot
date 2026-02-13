# Cross-Reference: OpenClaw Setup Guide vs. Minibot Repository

Each section of the OpenClaw guide is evaluated below for relevance to minibot, whether the suggestion holds up technically, and what concrete changes would bring minibot in line with the best practices described.

---

## Pre-Setup: Threat Model

**Verdict: Mostly relevant, adopt the framing.**

The threat categories map well to minibot's architecture, though the specifics differ (minibot doesn't have a "ClawHub" skill store or Telegram channel). The ones that apply directly:

- **Credential harvesting.** This is the big one. Before our last round of changes, minibot stored `POSTGRES_PASSWORD` in a plaintext `.env` file. The keychain migration addressed this, but the guide raises a good point: `~/minibot/config/` may eventually hold API keys, tokens, or connection strings in YAML files. The `minibot-secrets.sh` tool should be the canonical path for *all* credentials, not just the Postgres password.
- **Runaway automation loops.** Relevant once the orchestrator is live. Minibot currently has no resource limits on the orchestrator container.
- **Memory poisoning / prompt injection.** Relevant once agents are running. Not actionable yet, but the SOUL.md pattern (Phase 2D) is worth adopting preemptively.

**Changes needed:**
- Add a `docs/threat-model.md` to the repo documenting what minibot is defending against, even if brief.
- Expand `REQUIRED_SECRETS` in `minibot-secrets.sh` to anticipate future keys (API tokens, bot tokens, etc.) — or at minimum document that this is the expected pattern.

---

## Phase 1A: Mac Mini Initial Setup (1.1–1.8)

**Verdict: Good practices, several already covered, a few gaps.**

| Step | OpenClaw guide | Minibot status | Action needed? |
|------|---------------|----------------|----------------|
| FileVault | Enable full-disk encryption | Not mentioned anywhere | Add to `minibot-macos-setup.md`. Important for a dedicated machine. |
| Firewall | Turn on macOS firewall | Not mentioned | Add to setup guide. One line in System Settings. |
| Xcode CLI tools | `xcode-select --install` | Not mentioned | Add. Homebrew and git depend on it; it'll be prompted anyway, but making it explicit avoids confusion. |
| Homebrew install | Same approach | Already covered | No change. |
| Node.js | `brew install node@22` | minibot installs `node@20` | **Check compatibility.** Node 20 is LTS until April 2026, Node 22 is current LTS. Either is fine, but minibot should pin a version and document why. |
| Docker Desktop | `brew install --cask docker` | Fixed in last round | Already correct. |
| Git | `brew install git` | Already covered | No change. |

**Key difference:** The OpenClaw guide tells users to skip iCloud on a dedicated machine. Minibot's `minibot-macos-setup.md` already covers this under "Disable iCloud integration." Good alignment.

**Changes needed:**
- Add FileVault and firewall steps to `minibot-macos-setup.md` section on user account configuration.
- Add `xcode-select --install` before the Homebrew step in both the README and setup guide.

---

## Phase 1B: Install OpenClaw (1.1–1.3)

**Verdict: Not directly applicable (minibot isn't OpenClaw), but the pattern of version-checking and health-checking is worth adopting.**

The `openclaw doctor` and `openclaw --version` steps are about ensuring the install isn't vulnerable. Minibot doesn't have a CLI tool, but the equivalent would be:

**Changes needed:**
- The `health-check.sh` script should print version information for key dependencies (Docker, docker compose, Node, Python, Postgres image tag, Redis image tag). Currently it only checks Docker's version. Add something like:

```bash
echo "Docker Compose:" && docker compose version
echo "PostgreSQL image:" && docker inspect minibot-postgres --format='{{.Config.Image}}' 2>/dev/null
echo "Redis image:" && docker inspect minibot-redis --format='{{.Config.Image}}' 2>/dev/null
```

---

## Phase 1C: Onboarding Wizard (Model/Auth Setup)

**Verdict: The model-provider setup is OpenClaw-specific, but the secrets management pattern validates our keychain approach.**

The OpenClaw guide stores API keys via `openclaw models auth add`, which writes them to `~/.openclaw/credentials/` — plaintext files that Phase 2G then has to `chmod 700`. This is exactly the pattern minibot avoided by going straight to the keychain.

However, the guide raises a good structural point: minibot should anticipate **multiple secrets of different types** (not just `POSTGRES_PASSWORD`). When the orchestrator goes live, you'll likely need API keys for LLM providers, bot tokens for messaging platforms, etc.

**Changes needed:**
- Expand the `REQUIRED_SECRETS` array or add a comment showing the expected growth pattern:

```bash
REQUIRED_SECRETS=(
    POSTGRES_PASSWORD
    # Future:
    # ANTHROPIC_API_KEY
    # TELEGRAM_BOT_TOKEN
    # REDIS_PASSWORD
)
```

- Consider adding a `REDIS_PASSWORD` now. The current `docker-compose.yml` runs Redis with no authentication at all, which is fine on localhost but bad practice if the network configuration ever changes.

---

## Phase 1D–1E: Telegram / Test Conversation

**Verdict: Not applicable to minibot's current scope.** Minibot doesn't have a messaging channel. Skip.

---

## Phase 2A: Security Hardening

**Verdict: The `security audit` concept is excellent. Minibot should adopt a version of it.**

The OpenClaw `security audit` command checks for common misconfigurations. Minibot's `health-check.sh` is the closest equivalent, but it only checks service liveness, not security posture.

**Changes needed:**
Add a `scripts/security-audit.sh` that checks:

```bash
# 1. Are ports bound to localhost only?
docker compose -f ~/minibot/docker/docker-compose.yml port postgres 5432
# Should show 0.0.0.0:5432 → flag as warning if not 127.0.0.1:5432

# 2. Is the Postgres password set via keychain (not a default)?
PASS=$(~/minibot/bin/minibot-secrets.sh get POSTGRES_PASSWORD 2>/dev/null)
if [ "$PASS" = "changeme" ]; then echo "⚠ POSTGRES_PASSWORD is still the default!"; fi

# 3. Are file permissions correct on config/?
find ~/minibot/config -perm -o+r -type f  # Should find nothing

# 4. Is Redis running without a password?
docker exec minibot-redis redis-cli ping  # If this works with no auth, flag it

# 5. Is Docker running?
docker info &>/dev/null || echo "✗ Docker is not running"
```

This is a high-value addition for relatively little effort.

---

## Phase 2B: Docker Sandbox

**Verdict: Highly relevant. Minibot's compose file is missing several hardening options.**

The OpenClaw guide sets memory limits, CPU limits, PID limits, and network isolation on sandbox containers. Minibot's `docker-compose.yml` has **none of these**. The Postgres and Redis containers run with unlimited resources and full bridge network access.

**Changes needed for `docker/docker-compose.yml`:**

1. **Bind ports to localhost only.** Currently `"5432:5432"` binds to `0.0.0.0` (all interfaces). On a Mac with a firewall off or misconfigured, this exposes Postgres to the LAN.

```yaml
ports:
  - "127.0.0.1:5432:5432"   # was "5432:5432"
  - "127.0.0.1:6379:6379"   # was "6379:6379"
```

This is the single most important security fix from this cross-reference.

2. **Add resource limits.** Prevents a runaway query or Redis memory leak from consuming the whole machine:

```yaml
postgres:
  deploy:
    resources:
      limits:
        memory: 512M
        cpus: '1.0'

redis:
  deploy:
    resources:
      limits:
        memory: 256M
        cpus: '0.5'
```

3. **Add a Redis password.** Currently Redis has no authentication:

```yaml
redis:
  command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD:?Set via minibot-secrets.sh init}
```

And add `REDIS_PASSWORD` to `REQUIRED_SECRETS` in `minibot-secrets.sh`.

4. **Use an internal-only network for inter-service traffic.** The orchestrator comment already uses a `minibot-net` bridge, which is fine. But Postgres and Redis don't need *any* port exposure if the only consumer is the orchestrator container on the same Docker network. Once the orchestrator is uncommented, the `ports:` blocks on Postgres and Redis should be removed (or moved to a `docker-compose.dev.yml` override for local debugging).

---

## Phase 2C: Tool Policy Lockdown

**Verdict: Not directly applicable (minibot doesn't have an agent tool system yet), but the principle of deny-by-default is worth encoding.**

When the orchestrator goes live, the equivalent would be agent capability configuration in `config/agents/*.yaml`. No changes needed now, but worth a note in `docs/`.

---

## Phase 2D: SOUL.md — Agent Identity & Boundaries

**Verdict: Not applicable yet, but the template is worth including.**

**Changes needed:**
- Add a `config/agents/SOUL.md.example` template file to the repo, adapted from the OpenClaw guide but generalized. This gives future agent developers a starting point with the security boundaries already sketched out.

---

## Phase 2E: Tailscale Remote Access

**Verdict: Good approach for remote access. Validates minibot's `127.0.0.1` binding.**

The OpenClaw guide recommends Tailscale for remote access rather than exposing ports. This is sound advice and reinforces why the port-binding fix above (localhost only) matters. If someone wants remote access to the minibot control plane, Tailscale or SSH tunneling is the right answer — not binding to `0.0.0.0`.

**Changes needed:**
- Add a brief section to `minibot-macos-setup.md` noting that remote access should use Tailscale or SSH, never public port exposure. No code changes needed.

---

## Phase 2F: API Spending Limits

**Verdict: Not applicable to minibot's infrastructure layer.** This is about LLM API billing. When agents are added, this becomes relevant to agent configuration, not the base repo.

---

## Phase 2G: File Permissions

**Verdict: Relevant and currently missing from minibot.**

The OpenClaw guide does `chmod 700` on its config directory. Minibot doesn't set any file permissions during install. The `config/` directory may contain sensitive YAML files (agent definitions with embedded credentials, environment configs, etc.), and `data/` contains raw database files.

**Changes needed in `install.sh`:**

```bash
# After copying files
chmod 700 ~/minibot/config
chmod 700 ~/minibot/data
chmod 600 ~/minibot/config/environments/*.env 2>/dev/null
```

Also add to `setup-minibot-dirs.sh` so permissions are correct from initial creation.

---

## Phase 2H: LaunchAgent (24/7 Operation)

**Verdict: Relevant, and minibot has no equivalent.**

If minibot is meant to run on a dedicated Mac Mini, it should start on boot. Currently there's no LaunchAgent.

**Changes needed:**
- Add a `scripts/install-launchagent.sh` that creates `~/Library/LaunchAgents/com.minibot.gateway.plist` pointing to `minibot-start.sh`.
- Add a `scripts/uninstall-launchagent.sh` for clean removal.
- The plist should use `RunAtLoad`, `KeepAlive`, and route stdout/stderr to `~/minibot/data/logs/system/`.
- Document the "prevent sleep" System Settings step in the setup guide.

---

## Phase 3: Matrix Migration

**Verdict: Not applicable.** Messaging channel choice is an agent-layer concern, not infrastructure.

---

## Maintenance & Updates

**Verdict: Two good practices missing from minibot.**

1. **Credential rotation.** The OpenClaw guide recommends rotating all credentials every 3 months. Minibot's `minibot-secrets.sh` makes this easy (just `mb-secrets set POSTGRES_PASSWORD` and restart), but the workflow isn't documented. Add a `docs/maintenance.md` or a section in the README.

2. **Checking for exposed ports.** The guide suggests verifying from an external device that ports aren't reachable. This is exactly what the proposed `security-audit.sh` should check.

**Changes needed:**
- Document a rotation procedure in the README or a maintenance doc.
- The `backup.sh` script should be enhanced to note that after restoring, secrets still live in the keychain (not in the backup), so a fresh machine needs `minibot-secrets.sh init` after restore.

---

## Emergency Procedures

**Verdict: Minibot needs an equivalent.**

The OpenClaw guide's emergency procedures are well-structured: stop gateway → revoke credentials → inspect → rebuild. Minibot's `reset.sh` is the "nuclear option" but there's no documented triage process for a suspected compromise.

**Changes needed:**
- Add a `docs/emergency.md` covering:
  1. Stop services: `mb-stop`
  2. Rotate secrets: `mb-secrets set POSTGRES_PASSWORD` (new value)
  3. Inspect recent activity: check `data/logs/`
  4. If confirmed compromise: `scripts/reset.sh` + rebuild
- The `reset.sh` script should also rotate keychain secrets (or at least prompt the user to do so).

---

## Summary of Recommended Changes

Grouped by priority:

### High priority (security impact)

| Change | File(s) affected |
|--------|-----------------|
| Bind ports to `127.0.0.1` only | `docker/docker-compose.yml` |
| Add Redis authentication | `docker/docker-compose.yml`, `minibot-secrets.sh` |
| Set file permissions on `config/` and `data/` | `install.sh`, `setup-minibot-dirs.sh` |
| Add FileVault + firewall to setup guide | `minibot-macos-setup.md` |

### Medium priority (operational robustness)

| Change | File(s) affected |
|--------|-----------------|
| Add container resource limits (memory, CPU) | `docker/docker-compose.yml` |
| Add `xcode-select --install` step | `README.md`, `minibot-macos-setup.md` |
| Create `scripts/security-audit.sh` | New file |
| Add version info to `health-check.sh` | `scripts/health-check.sh` |
| Add LaunchAgent for boot persistence | New files in `scripts/` |
| Document credential rotation | `README.md` or new `docs/maintenance.md` |

### Low priority (future-proofing)

| Change | File(s) affected |
|--------|-----------------|
| Add `SOUL.md.example` template | New file in `config/agents/` |
| Add `docs/threat-model.md` | New file |
| Add `docs/emergency.md` | New file |
| Note Tailscale/SSH for remote access | `minibot-macos-setup.md` |
| Expand `REQUIRED_SECRETS` with commented future keys | `bin/minibot-secrets.sh` |
