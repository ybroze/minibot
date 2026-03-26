<p align="center">
  <img src="minibot.webp" alt="Minibot">
</p>

# Minibot

Scripts and configuration for running an isolated AI agent environment on
dedicated macOS hardware (Apple Silicon Mac Mini). A dedicated `minibot` user
runs Docker Compose to orchestrate service containers, with secrets in the
macOS Keychain and networking locked to localhost.

## Setup

### 1. Harden the Machine (as admin)

These steps secure the base system before anything else. Do them once.

- **System Update:** Software Update to macOS Sequoia (15.x) or later.
- **FileVault:** System Settings > Privacy & Security > FileVault > Turn On.
  Save the recovery key in a password manager.
- **Firewall:** System Settings > Network > Firewall > Turn On.
- **Advanced Data Protection:** System Settings > Apple ID > iCloud > Advanced Data Protection > Turn On.
- **Remote Login (SSH):** System Settings > General > Sharing > Remote Login > On.
  Required for headless operation — after reboot with FileVault, you unlock
  the disk remotely via SSH pre-boot prompt using the admin password.

> **CRITICAL:** Without FileVault, anyone with physical access can read all
> data by booting into recovery mode. Save the recovery key.

### 2. Install Dependencies (as admin)

```bash
cd ~/Downloads
git clone https://github.com/ybroze/minibot.git
bash minibot/scripts/admin-setup.sh
```

This installs Xcode CLI Tools, Homebrew, Docker Desktop, Tailscale, CLI debug
tools, creates the `minibot` user, and configures energy settings for 24/7
headless operation. Each step is idempotent.

<details>
<summary>Manual alternative</summary>

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install --cask docker tailscale
brew install libpq redis mongosh
```

</details>

After installing, complete the GUI-only steps:

- Open Docker Desktop (`open -a Docker`), accept the license, enable
  "Start Docker Desktop when you sign in" (this is per-user — repeat as
  `minibot` in step 4).
- Open Tailscale, log in, approve the system extension and VPN prompts.

### 3. Set Up Remote Access

**Tailscale** provides the network layer. Install it on any device you want
remote access from and log in with the same account. Verify with
`tailscale status` — all devices should appear with `100.x.x.x` addresses.

**Screen Sharing** provides graphical remote desktop over Tailscale. Enable it
on the minibot machine: System Settings > General > Sharing > Screen Sharing >
On. From another Mac on your tailnet, connect via Finder > Go > Connect to
Server > `vnc://<tailscale-ip>`, or open Screen Sharing.app directly.

### 4. Create and Configure the `minibot` User

If `admin-setup.sh` created the user, skip to logging in.
Otherwise: System Settings > Users & Groups > Add Account > Standard,
name `minibot`, strong password saved in a password manager.

Log in as `minibot`. Optionally harden the account:

- Disable iCloud sync: System Settings > Apple ID > iCloud > Turn off all
- Disable Siri: System Settings > Siri & Spotlight > off
- Disable Location Services: System Settings > Privacy & Security > off

### 5. Install Minibot (as `minibot` user)

Docker Desktop must be running. Open it if needed, wait for the whale icon to
settle, and enable "Start Docker Desktop when you sign in."

```bash
cd ~/Downloads
git clone https://github.com/ybroze/minibot.git
bash minibot/install.sh
source ~/.zshrc
```

The installer creates directories, copies scripts, configures the shell,
prompts for secrets (stored in the macOS Keychain), builds the `openclaw:local`
Docker image from source, verifies Ollama is running (managed by the separate
`ollama` user), and installs LaunchAgents.

All secrets (`POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `MONGO_PASSWORD`,
`OPENCLAW_GATEWAY_PASSWORD`) live in the macOS Keychain and are managed through
`mb-secrets`. OpenClaw manages its own internal secrets (API keys, bot tokens)
separately.

### 6. Configure API Spending Limits

Before starting services, set spending limits on each external API provider's
dashboard. For each key: set daily/monthly caps, enable alerts at 50% and 80%,
and prefer prepaid billing where available. API keys are managed by OpenClaw
internally, not through `mb-secrets`.

### 7. Start Services

```bash
mb-start        # Load secrets from Keychain, start containers
mb-status       # Check container status
mb-logs         # Follow live logs
```

#### Resource Limits (16 GB Mac Mini)

| Service    | Container/Process  | Memory | CPUs | Notes |
|------------|--------------------|--------|------|-------|
| PostgreSQL | minibot-postgres   | 1 GB   | 1.0  | Query caching, shared buffers |
| Redis      | minibot-redis      | 256 MB | 0.5  | Cache/message broker |
| MongoDB    | minibot-mongo      | 1 GB   | 1.0  | WiredTiger cache |
| OpenClaw   | minibot-openclaw   | 4 GB   | 2.0  | Node.js heap 3.5 GB |
| Ollama     | native             | ~4.9 GB | all | Llama 3.1 8B Q4, Metal GPU |
| **Total**  |                    | **~11.5 GB** | | |

macOS + Remote Desktop use ~3-4 GB on a headless machine (no GUI session),
leaving ~1.5-2.5 GB headroom. Ollama runs natively with Metal GPU acceleration,
binding to localhost only.

### 8. Enable 24/7 Operation

The installer sets up two LaunchAgents for the `minibot` user:

- **com.minibot.gateway** — starts Docker services on login
- **com.minibot.caffeinate** — prevents system sleep

Ollama runs under the separate `ollama` user with its own LaunchAgent
(`com.ollama.serve`), installed by `scripts/install-ollama-user.sh`.

Verify minibot LaunchAgents are loaded:

```bash
launchctl list | grep minibot
```

**With FileVault (recommended):** Auto-login is disabled by macOS. After each
reboot you must unlock the disk via SSH pre-boot prompt (admin password), then
start the `minibot` session via SSH or Screen Sharing. Once the
session starts, all LaunchAgents fire automatically.

**Without FileVault:** Auto-login is available (System Settings > Users &
Groups > Automatic login > `minibot`). The machine recovers fully
unattended after reboot.

Sleep prevention is handled by `admin-setup.sh` (`pmset` settings) plus the
caffeinate LaunchAgent.

Test: `sudo reboot`, then verify with `mb-status`.

---

## Shell Aliases

Available after `source ~/.zshrc`:

| Alias | Description |
|-------|-------------|
| `mb-start` | Load secrets, start all containers |
| `mb-stop` | Stop all containers |
| `mb-status` | Show container status |
| `mb-logs [service]` | Follow Docker logs |
| `mb-build` | Rebuild OpenClaw from source |
| `mb-secrets <cmd>` | Manage Keychain secrets (`init`, `list`, `set`, `get`) |
| `mb-health` | Run health check |
| `mb-audit` | Run security audit |
| `mb-llm-status` | Check Ollama status (managed by `ollama` user) |
| `mb-llm-info` | Show Ollama management info |
## Directory Structure

```
~/minibot/
├── bin/                    # Operational scripts (start, stop, logs, secrets, llm)
├── data/                   # Persistent data (700 permissions)
│   ├── postgres/, redis/, mongo/, openclaw/
│   └── logs/system/        # LaunchAgent logs
├── docker/                 # docker-compose.yml
├── scripts/                # Maintenance (backup, restore, health-check,
│                           #   security-audit, reset, LaunchAgents, etc.)
├── vendor/openclaw/        # OpenClaw source (created by mb-build)
├── docs/                   # Detailed documentation
└── zshrc-additions.sh      # Shell config (sourced by ~/.zshrc)
```

## Documentation

| Topic | File |
|-------|------|
| Getting started | `GETTING_STARTED.md` |
| Threat model | `docs/THREAT-MODEL.md` |
| Secrets management | `docs/SECRETS.md` |
| Networking & ports | `docs/NETWORKING.md` |
| Maintenance & rotation | `docs/MAINTENANCE.md` |
| Emergency procedures | `docs/EMERGENCY.md` |
| Containerization security | `docs/SECURITY.md` |
| Filesystem security | `docs/FILESYSTEM.md` |

## Troubleshooting

**Docker not starting** — Run `open -a Docker`, wait 30-60s for the whale
icon to settle, then `mb-start`.

**Secrets missing** — Run `mb-secrets init` then `mb-secrets list` to verify.

**OpenClaw won't start** — Check `docker image inspect openclaw:local` (run
`mb-build` if missing), then `mb-logs openclaw` for errors.

**Database connection errors** — Check `docker logs minibot-postgres`,
verify `mb-secrets get POSTGRES_PASSWORD` returns a value.

**Disk space** — `du -sh ~/minibot/data/*` and `docker system prune`.

---

## Environment Cleanup (optional)

For a dedicated machine, you can remove unused macOS apps (Music, TV,
FaceTime, Keynote, etc.) by dragging from `/Applications` to Trash.
SIP-protected apps can be ignored.

```bash
# As admin: disable Spotlight on data directory
sudo mdutil -i off ~/minibot/data

# As minibot: disable App Store auto-updates (also offered during install)
defaults write com.apple.commerce AutoUpdate -bool false
```
