# Minibot Threat Model

This document outlines the threats that the Minibot environment is designed to
defend against. Understanding these helps explain why the setup is configured
the way it is.

---

## Threat 1: Credential Theft

**What:** An attacker (malware, a compromised dependency, or a malicious agent
skill) reads credentials stored on disk.

**Minibot's posture:** Secrets are stored in the macOS Keychain, not in
plaintext `.env` files. The keychain is encrypted at rest (backed by
FileVault) and requires user authentication to unlock.

**Residual risk:** Secrets are briefly present in shell environment variables
when `minibot-start.sh` runs. A process running as the same user during that
window could read `/proc/<pid>/environ` (on Linux) or equivalent. On macOS
this is mitigated by SIP and per-user process isolation, but it is not zero
risk.

Additionally, Docker exposes container environment variables (including
interpolated secrets like `POSTGRES_PASSWORD`, `REDIS_PASSWORD`,
`MONGO_PASSWORD`, `OPENCLAW_GATEWAY_PASSWORD`) to anyone
who can run `docker inspect` on the host. Docker socket access is effectively
root-equivalent, so on a shared machine this is a real concern. On a
single-user dedicated machine the risk is lower but worth documenting.

**Mitigations in place:**
- `umask 077` ensures all new files are owner-only by default.
- `data/` is set to `700` during install.
- `security-audit.sh` checks for permission drift and incorrect umask.
- Files created inside Docker volumes (e.g., logs) may be owned by root or
  the container's internal user. The `700` on the parent `data/` directory
  prevents other host users from traversing into them.

---

## Threat 2: Network Exposure

**What:** Services like PostgreSQL or Redis are reachable from the local
network (or worse, the internet), allowing unauthenticated access.

**Minibot's posture:**
- All Docker ports are bound to `127.0.0.1` (localhost only).
- Redis requires a password (`--requirepass`).
- The macOS firewall is enabled.
- Remote access is via Tailscale or SSH tunnel — never by opening ports.

**Residual risk:** If someone gains shell access to the minibot user account,
they can connect to localhost services directly.

---

## Threat 3: Runaway Automation

**What:** A buggy or manipulated agent enters an infinite loop, consuming
unbounded CPU, memory, or API credits.

**Minibot's posture:**
- Docker containers have memory and CPU limits (`deploy.resources.limits`).
- API spending limits should be set on provider dashboards (documented in
  setup guide, but enforced externally).

**Residual risk:** The limits prevent host exhaustion but don't prevent the
agent from burning through its allocated resources or API budget within limits.

---

## Threat 4: Prompt Injection / Memory Poisoning

**What:** An attacker crafts input (a message, email, document) that contains
hidden instructions. When the agent processes this input, it follows the
injected instructions instead of (or in addition to) the user's intent.

**Minibot's posture:**
- Agents should have hard boundaries configured within OpenClaw.
- Tool policies should deny dangerous capabilities by default.
- The Docker sandbox limits blast radius even if the agent is tricked.

**Residual risk:** No current LLM is fully immune to prompt injection. Defense
in depth (OpenClaw agent boundaries + tool policy + Docker sandbox) reduces
impact but does not eliminate the risk.

---

## Threat 5: Supply Chain Compromise

**What:** A Docker image, Homebrew package, npm module, or agent skill
contains malicious code.

**Minibot's posture:**
- Docker images are pinned to specific tags where available (e.g.,
  `postgres:15-alpine`). The OpenClaw image uses `latest` until stable
  versioned tags are published.
- Homebrew auto-update is disabled (`HOMEBREW_NO_AUTO_UPDATE=1`).
- The setup guide recommends reviewing skills/plugins before installation.

**Residual risk:** Pinned tags can be re-tagged upstream (use digests for
stronger guarantees). Homebrew formulae are not audited for every update.

---

## Threat 6: Physical Access

**What:** Someone with physical access to the Mac Mini boots into recovery
mode, resets the admin password, and reads all data.

**Minibot's posture:**
- FileVault encrypts the entire disk.
- The recovery key should be stored in a password manager, not on the device.

**Residual risk:** A sufficiently motivated attacker with physical access and
the recovery key (or a firmware exploit) can still compromise the machine.

---

## Review Cadence

Review this threat model whenever you:
- Add a new agent or skill
- Expose a new service or port
- Change the network configuration
- Add a new secret or credential
