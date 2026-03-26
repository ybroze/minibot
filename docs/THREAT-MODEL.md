# Minibot Threat Model

This document outlines the threats that the Minibot environment is designed to
defend against. Understanding these helps explain why the setup is configured
the way it is.

**Environment:** Dedicated Mac Mini (Apple M4, 16 GB RAM) running macOS Tahoe,
headless operation. Two standard user accounts: `minibot` (Docker containers,
secrets, agent infrastructure) and `ollama` (isolated LLM runner). Four Docker
containers (PostgreSQL, Redis, MongoDB, OpenClaw) plus a native Ollama server
(Llama 3.1 8B, Metal GPU) under the `ollama` user. Remote access via Tailscale
and Screen Sharing.

---

## Threat 1: Credential Theft

**What:** An attacker (malware, a compromised dependency, or a malicious agent
skill) reads credentials stored on disk or in the process environment.

**Minibot's posture:** Secrets are stored in the macOS Keychain, not in
plaintext `.env` files. The keychain is encrypted at rest (backed by
FileVault) and requires user authentication to unlock.

**Mitigations in place:**
- `umask 077` ensures all new files are owner-only by default.
- `data/` is set to `700` during install.
- `security-audit.sh` checks for permission drift and incorrect umask.
- Files created inside Docker volumes (e.g., logs) may be owned by root or
  the container's internal user. The `700` on the parent `data/` directory
  prevents other host users from traversing into them.

**Residual risk:** Secrets are present as shell environment variables for the
duration of every `minibot` login session (loaded by `zshrc-additions.sh`).
Any process running as the `minibot` user — including agent skills and
Ollama — can read them via `/proc` or the process environment. On macOS, SIP
and per-user process isolation prevent other users' processes from accessing
them, but any code running as `minibot` has full access.

Docker exposes container environment variables (including interpolated secrets)
to anyone who can run `docker inspect` on the host. Docker socket access is
effectively root-equivalent. On a dedicated single-user machine the risk is
lower but worth documenting.

---

## Threat 2: Network Exposure

**What:** Services are reachable from the local network or the internet,
allowing unauthenticated or unauthorized access.

**Minibot's posture:**
- All Docker ports are bound to `127.0.0.1` (localhost only).
- Ollama binds to `127.0.0.1:11434` (localhost only).
- Redis requires a password (`--requirepass`).
- PostgreSQL and MongoDB require authentication.
- The macOS firewall is enabled with stealth mode.
- Remote access is via Tailscale or SSH tunnel — never by opening ports.

**Port inventory:**

| Service    | Port  | Auth required | Reachable from |
|------------|-------|---------------|----------------|
| PostgreSQL | 5432  | Yes (password) | localhost only |
| Redis      | 6379  | Yes (password) | localhost only |
| MongoDB    | 27017 | Yes (password) | localhost only |
| OpenClaw   | 18789 | Yes (gateway password) | localhost only |
| Ollama     | 11434 | **No** | localhost + Docker containers |

**Cross-boundary access:** Docker containers can reach Ollama via
`host.docker.internal:11434`. This means a compromised container can use the
local LLM without authentication. This is by design — OpenClaw and agents need
LLM access — but it means Ollama is exposed to any code running inside any
container on the Docker bridge network.

**Residual risk:** If someone gains shell access to the `minibot` user account,
they can connect to all localhost services directly. Ollama's lack of
authentication means any localhost process can make inference requests — there
is no way to restrict which processes can use the LLM.

---

## Threat 3: Runaway Automation

**What:** A buggy or manipulated agent enters an infinite loop, consuming
unbounded CPU, memory, or API credits.

**Minibot's posture:**
- Docker containers have memory and CPU limits (`deploy.resources.limits`):
  PostgreSQL 1 GB, Redis 256 MB, MongoDB 1 GB, OpenClaw 4 GB.
- API spending limits should be set on provider dashboards (documented in
  setup guide, but enforced externally).

**Ollama has no resource limits.** Unlike the Docker containers, Ollama runs
as an unrestricted native process. It can consume all available RAM (~5-6 GB
after containers and macOS overhead) and all CPU cores. On a 16 GB machine,
a runaway inference loop — or multiple concurrent requests — could cause
memory pressure, swap thrashing, and degrade all other services.

**Mitigations available but not yet implemented:**
- Ollama supports `OLLAMA_MAX_LOADED_MODELS` and `OLLAMA_NUM_PARALLEL` to
  limit concurrent model loading and parallel requests.
- macOS does not provide per-process memory limits for non-containerized
  processes (unlike Linux cgroups). The only hard boundary is physical RAM.

**Residual risk:** The Docker limits prevent container-side host exhaustion,
but Ollama is the most likely source of resource contention. A single large
context request or a burst of concurrent requests could temporarily starve
the Docker containers of memory.

---

## Threat 4: Prompt Injection / Memory Poisoning

**What:** An attacker crafts input (a message, email, document) that contains
hidden instructions. When an agent processes this input, it follows the
injected instructions instead of (or in addition to) the user's intent.

**Minibot's posture:**
- Agents should have hard boundaries configured within OpenClaw.
- Tool policies should deny dangerous capabilities by default.
- The Docker sandbox limits blast radius even if an agent is tricked.

**Local LLM dimension:** With Ollama available on localhost, a prompt injection
attack now has two potential targets:
1. **External API models** (e.g., Anthropic, OpenAI) — rate-limited and
   metered by provider spending caps.
2. **Local Ollama model** — no rate limiting, no cost per request, no
   authentication. An injected prompt that causes an agent to loop against
   the local LLM can run indefinitely without hitting a spending cap.

**Residual risk:** No current LLM is fully immune to prompt injection. Defense
in depth (OpenClaw agent boundaries + tool policy + Docker sandbox) reduces
impact but does not eliminate the risk. The local LLM adds a new dimension:
runaway loops against Ollama are free in dollar terms but expensive in compute.

---

## Threat 5: Supply Chain Compromise

**What:** A Docker image, Homebrew package, npm module, Ollama model, or agent
skill contains malicious code.

**Minibot's posture:**
- Docker images are pinned to specific tags where available (e.g.,
  `postgres:15-alpine`). The OpenClaw image is built from source
  (`openclaw:local`) using the default branch of the upstream repository.
- Homebrew auto-update is disabled (`HOMEBREW_NO_AUTO_UPDATE=1`).
- The setup guide recommends reviewing skills/plugins before installation.

**Ollama model supply chain:** `ollama pull` downloads models from the Ollama
registry (registry.ollama.ai). A compromised or trojaned model could:
- Exploit a parsing vulnerability in the inference engine (llama.cpp under the
  hood) to achieve code execution.
- Contain biased or poisoned weights that produce harmful outputs without
  triggering obvious errors.

Ollama verifies model checksums during download, but the registry itself is a
trust anchor — if the registry is compromised, checksums are useless. Stick to
well-known models (e.g., `llama3.1`, `qwen2.5`) from the official library.

**Residual risk:** Pinned Docker tags can be re-tagged upstream (use digests
for stronger guarantees). Homebrew formulae are not audited for every update.
Ollama models are downloaded from a single registry with no independent
verification mechanism.

---

## Threat 6: Physical Access

**What:** Someone with physical access to the Mac Mini boots into recovery
mode, resets the admin password, and reads all data.

**Minibot's posture:**
- FileVault encrypts the entire disk.
- The recovery key should be stored in a password manager, not on the device.
- After reboot with FileVault, the disk must be unlocked via SSH pre-boot
  prompt before any data is accessible.

**Residual risk:** A sufficiently motivated attacker with physical access and
the recovery key (or a firmware exploit) can still compromise the machine.
Cold boot attacks against Apple Silicon are not known to be practical, but
physical access is physical access.

---

## Threat 7: Local LLM Compromise (Ollama)

**What:** The Ollama server process is exploited — via a crafted API request,
a malicious model, or a vulnerability in the inference engine — and the attacker
attempts to read files, exfiltrate data, or pivot to other services on the host.

**Minibot's posture — user-level isolation:** Ollama runs under a dedicated
`ollama` standard user account that is completely separate from the `minibot`
user. This provides strong Unix permission boundaries:

| Resource | `ollama` user access | `minibot` user access |
|----------|---------------------|----------------------|
| Minibot secrets (Keychain) | **No** | Yes |
| Docker socket | **No** | Yes |
| `~/minibot/` (scripts, data, config) | **No** | Yes |
| Database volumes (Postgres, Mongo, Redis) | **No** | Yes |
| Ollama model files (`~/.ollama/`) | Yes | **No** |
| Ollama API (localhost:11434) | Yes | Yes (read-only) |
| Other user accounts' data | **No** | **No** |

A compromised Ollama process is confined to the `ollama` user, which has:
- No secrets in its environment
- No Docker socket access
- No access to minibot's home directory, scripts, or data
- No `sudo` privileges (standard account)
- Only its own home directory, Ollama model files, and the Ollama binary

**Additional mitigations:**
- Ollama binds to `127.0.0.1:11434` — not reachable from outside the machine.
- The macOS firewall blocks unsolicited inbound connections.
- Ollama is managed by a LaunchAgent (`com.ollama.serve`) with KeepAlive.
- The `minibot` user cannot start or stop Ollama (clean separation).

**Residual risk:**
- Ollama's API has no authentication. Any process on localhost (including all
  Docker containers via `host.docker.internal`) can make requests. This is by
  design but means a compromised container can use the LLM freely.
- A compromised `ollama` user can still read world-readable files, access
  `/tmp`, and make outbound network connections. It cannot read minibot's data
  (protected by `700` permissions and per-user Keychain isolation).
- Model parsing vulnerabilities in llama.cpp could be triggered by a malicious
  GGUF file. Only use models from the official Ollama registry.

**Recovery:** If the Ollama process is compromised:
1. Log in as `ollama` and stop: `pkill -f "ollama serve"`
2. The `minibot` user's secrets were **not** accessible — no credential
   rotation needed unless the compromise vector was outside the `ollama` user.
3. Inspect logs: `tail ~ollama/ollama-data/logs/ollama-stderr.log`
4. Replace the model: `ollama rm llama3.1:8b && ollama pull llama3.1:8b`
5. If the compromise extended beyond the `ollama` user (e.g., kernel exploit),
   treat as a full machine compromise — see `docs/EMERGENCY.md`.

---

## Threat 8: Container-to-Host Escalation via Ollama

**What:** A compromised Docker container uses the Ollama API
(`host.docker.internal:11434`) to attack the host indirectly — by generating
malicious payloads, exfiltrating data through inference requests, or exploiting
Ollama vulnerabilities to gain host-level code execution.

**Why this matters:** Docker containers are designed to be isolated from the
host, but the Ollama API creates an intentional bridge. Any container on the
`minibot-net` network can reach `host.docker.internal:11434` without
authentication. This is a designed capability (agents need LLM access) but it
means a compromised container has a communication channel to a host process.

**Attack scenarios:**
- **Data exfiltration via prompts:** A compromised container sends sensitive
  data (database contents, secrets) as part of inference prompts. If Ollama
  logs prompts, the data lands on the host filesystem.
- **Ollama exploit:** A crafted API request triggers a vulnerability in
  Ollama's HTTP handler or inference engine, leading to code execution on the
  host as the `ollama` user (isolated — no access to secrets or Docker).
- **Resource exhaustion:** A container floods Ollama with large-context requests,
  causing memory pressure that degrades or crashes other services.

**Minibot's posture:**
- Docker containers have resource limits that bound their ability to generate
  flood traffic.
- Ollama's attack surface is limited to its HTTP API — there is no shell
  access, file upload, or arbitrary command execution exposed through the API.
- Ollama runs as the `ollama` user, not `minibot` — even if exploited, the
  attacker has no access to secrets, Docker, or minibot's data. The `ollama`
  user is a standard account with no `sudo` privileges.

**Residual risk:** The Ollama API bridge is an accepted trade-off. The attack
surface is real but narrow — it requires either an Ollama vulnerability or a
scenario where prompt content constitutes a data leak. Monitor Ollama releases
for security patches.

---

## Review Cadence

Review this threat model whenever you:
- Add a new agent or skill
- Expose a new service or port
- Change the network configuration
- Add a new secret or credential
- Change the LLM model or Ollama configuration
- Update Ollama (check release notes for security fixes)
- Grant a container access to new host resources
