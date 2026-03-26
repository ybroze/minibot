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

**Residual risk:** Secrets are present as shell environment variables for the
duration of every `minibot` login session (loaded by `zshrc-additions.sh`).
A process running as the same user can read them via the process environment.
On macOS this is mitigated by SIP and per-user process isolation, but it is
not zero risk — any code running as the `minibot` user (including agent
skills) can access these variables.

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
  `postgres:15-alpine`). The OpenClaw image is built from source
  (`openclaw:local`) using the default branch of the upstream repository.
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

## Threat 7: Local LLM Compromise (llama.cpp)

**What:** The llama.cpp server process is exploited — via a crafted API request,
a malicious model file, or a vulnerability in the inference engine — and the
attacker attempts to read files, exfiltrate data, or pivot to other services on
the host.

**Why this matters:** Unlike the Docker containers, the LLM runs as a native
macOS process under the `minibot` user. Without additional isolation, it would
have full access to the user's home directory, the Keychain, the Docker socket,
and all localhost services. A compromised LLM process could read secrets, modify
scripts, or interact with databases — effectively owning the entire minibot
environment.

**Minibot's posture:** The llama.cpp server runs inside a macOS `sandbox-exec`
profile (`etc/llama-sandbox.sb`) that enforces a deny-by-default policy at the
kernel level:

| Capability | Policy | Rationale |
|------------|--------|-----------|
| Filesystem (general) | **Deny** | No access to `~/`, `~/minibot/`, config files, scripts, or data directories |
| Model file | **Read-only** | The GGUF model in `data/models/` is the only readable user file |
| Homebrew & system libs | **Read-only** | Required for the binary and its dynamic libraries |
| Filesystem writes | **Deny** | Cannot create, modify, or delete any file anywhere |
| Network bind | **Allow localhost:8012** | The HTTP server must bind to serve requests |
| Network outbound | **Deny** | Cannot initiate connections to databases, the internet, or other services |
| Metal GPU (IOKit) | **Allow** | Required for Apple Silicon GPU acceleration |
| Mach IPC | **Allow** | Required for Metal framework communication with the GPU driver |
| Subprocess spawning | **Deny** | Cannot fork or exec other processes |
| Signals | **Self only** | Can only signal itself (graceful shutdown) |

**Rationale for each decision:**

- **No filesystem writes:** The LLM has no legitimate reason to write files.
  Denying writes prevents persistence (backdoors, modified scripts) even if
  the process is fully compromised.

- **No home directory access:** Prevents reading `~/.zshrc` (which contains
  the keychain export), `~/minibot/bin/` (scripts), `~/minibot/data/` (database
  volumes), and any other user files. The process cannot discover what else
  exists on the system.

- **No outbound network:** The server only needs to *accept* connections, not
  make them. Blocking outbound prevents data exfiltration to external servers
  and blocks lateral movement to PostgreSQL (5432), Redis (6379), MongoDB
  (27017), or OpenClaw (18789) on localhost.

- **Metal/Mach IPC allowed:** This is the broadest permission in the profile.
  Metal requires IOKit for GPU device access and Mach IPC for shader
  compilation and driver communication. `mach-lookup` is not scoped to specific
  services because Metal's internal service names are undocumented and vary
  across macOS versions. This is an acceptable trade-off: Mach IPC without
  filesystem or network access limits what an attacker can do through this
  channel.

- **Model file read-only:** The model is a ~4.4 GB binary blob (GGUF format).
  The sandbox allows reading only the `data/models/` directory. The model file
  is also set to `chmod 444` (read-only at the Unix level) as a secondary
  control.

**Residual risk:**
- The `mach-lookup` permission is broad. A sophisticated attacker with code
  execution inside the sandbox could potentially interact with other Mach
  services. In practice, without filesystem or network access, the attack
  surface is limited to IPC with system services that don't require
  authentication.
- The `sandbox-exec` mechanism is deprecated by Apple (no replacement yet) and
  may not be available in future macOS versions. Monitor Apple's security
  framework roadmap.
- A malicious or trojaned GGUF model file could exploit a parsing vulnerability
  in llama.cpp. The sandbox limits the blast radius, but the process does have
  Metal GPU access. Only use models from trusted sources (e.g., well-known
  HuggingFace uploaders).

**Recovery:** If the llama.cpp process is compromised:
1. `mb-llm-stop` (or `kill` the PID from `data/llm/llama.pid`)
2. The sandbox means no secrets or files were accessible — no credential
   rotation needed unless the compromise vector was *outside* the sandbox
3. Inspect `data/logs/system/llama-stderr.log` for anomalies
4. Consider replacing the model file if its integrity is in question

---

## Review Cadence

Review this threat model whenever you:
- Add a new agent or skill
- Expose a new service or port
- Change the network configuration
- Add a new secret or credential
- Change the LLM model or sandbox profile
- Update macOS (sandbox-exec behavior may change)
