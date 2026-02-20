# Minibot macOS Setup Scripts

This repository contains all the scripts and configuration files needed to set
up a clean, isolated Minibot environment on macOS. This assumes an install on
clean, dedicated hardware, such as an Apple Silicon MacMini.

Briefly, a dedicated `minibot` user is created, within which Docker is used to 
orchestrate service containers within a single Linux VM (a limitation of
Docker), with various networking and other safeguards in place.

# Quick Start

## Initial Machine Hardening

Before creating the dedicated user, secure the base system. These steps only
need to be done once per machine and require an admin account.

Create a strong password for the admin user of your choice, and ensure you
have saved it in a secure location or password manager.

### Perform System Upgrade
Ensure that all system updates and upgrades are done via the Software Update
tool. macOS Sequoia (15.x) or later is recommended.

### Enable FileVault (Full-Disk Encryption)

Go to **System Settings > Privacy & Security > FileVault > Turn On**.

> **CRITICAL:** Save the recovery key in a password manager or print it.
> Without FileVault, anyone with physical access to the machine can read all
> data, including keychain secrets, by booting into recovery mode.

**Note that remote login (Tahoe and later) is required to run headless.**

Enable "Remote Login" (SSH) in System Settings > General > Sharing.
After a reboot, connect via SSH from another machine — you'll get a
special pre-boot prompt:
"This system is locked. To unlock it, use a local account name and password."
FileVault being enabled *requires* a password on reboot, but with remote logins
via ssh (ie., with Tailscale), this can be administered. Caveat that each
reboot will require unlocking the encrypted disk using the administrator
password. Save your backup key.

### Enable the macOS Firewall

Go to **System Settings > Network > Firewall > Turn On**. This prevents
unsolicited inbound connections. Alternatively, via the command line:

```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
```

### Enable Advanced Data Protection for iCloud services

Go to **System Settings > Apple ID > iCloud > Advanced Data Protection > Turn On**.

## Configuration

### 1. Install Dependencies (as admin user)

Homebrew and its packages require administrator privileges. Run these steps
while logged in as your admin account — **not** the `minibot` user.

The fastest way is to run the admin setup script, which handles steps 1, 2,
5, and 6 in a single command:

```bash
# Clone the repo (if not already done)
cd ~/Downloads
git clone https://github.com/ybroze/minibot.git

# Run the admin setup script
bash minibot/scripts/admin-setup.sh
```

The script installs Xcode CLI Tools, Homebrew, Docker Desktop, Tailscale,
CLI debug tools, creates the `minibot` user, and configures sleep settings.
Each step is idempotent — safe to re-run.

<details>
<summary>Manual alternative (click to expand)</summary>

```bash
# Install Xcode Command Line Tools (required by Homebrew and Git)
xcode-select --install

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install core dependencies
brew install --cask docker              # Docker Desktop (daemon + CLI + Compose)

# Install Tailscale for secure remote access
brew install --cask tailscale

# Install CLI tools for debugging (psql, redis-cli, mongosh)
brew install libpq redis mongosh
```

</details>

After installing Docker Desktop, you must open it at least once to accept the
license agreement and let it start the Docker daemon:

```bash
open -a Docker
```

Wait for the whale icon in the menu bar to settle (no animation) before
running any `docker` commands. During first-run setup, enable
**"Start Docker Desktop when you sign in"** so it starts automatically on
future logins. Note that this setting is per-user — you will need to do this
again when you first open Docker Desktop as the `minibot` user in step 4.

### 1b. Set Up Tailscale

Tailscale creates a private mesh VPN between your devices so you can reach
the Minibot machine remotely without exposing any ports to the internet.

1. Open Tailscale from Applications and log in (or create an account).
   On first launch, macOS will prompt you to approve a system extension and
   a VPN configuration — allow both. The system extension approval may
   require your admin password.
2. Install Tailscale on any device you want remote access from (phone, laptop, etc.) and log in with the same account.
3. Verify connectivity:
   ```bash
   tailscale status
   ```
   You should see all your devices listed with `100.x.x.x` addresses.

Once connected, you can reach the Minibot machine from any device on your
tailnet using its Tailscale IP — no port forwarding or firewall changes needed.

### 2. Create the `minibot` User (as admin user)

If you ran `admin-setup.sh` in step 1, the user was already created — skip
to step 3.

Otherwise, create it via System Settings:

- Go to **System Settings > Users & Groups**
- Click **Add Account...**
- Select **Standard** account type
- Full name: `Minibot`
- Account name: `minibot`
- Set a strong password and save it in a password manager, or print it out.

### 3. Log in as `minibot` User

Log out of your admin account and log in as the `minibot` user. All remaining
steps are performed as `minibot`.

> **Note:** Homebrew and its packages (Docker, git, etc.) were installed
> system-wide by the admin user and are accessible to all users via
> `/opt/homebrew/bin`.

### 3b. Configure the `minibot` Account

The installer (`install.sh`, step 4) offers an optional account-hardening
step that removes unused directories and disables App Store auto-updates.
The following items are GUI-only and must be done manually:

- **Disable iCloud:** System Settings > Apple ID > iCloud > Turn off all sync services
- **Disable Siri:** System Settings > Siri & Spotlight > Disable "Ask Siri"
- **Disable location services:** System Settings > Privacy & Security > Location Services > Off

### 4. Install Minibot

> **Note:** Docker Desktop must be running before running the installer,
> because it builds the OpenClaw Docker image. Open it from Applications if
> it isn't already running and wait for the whale icon in the menu bar to
> settle. On first launch as the `minibot` user, enable **"Start Docker
> Desktop when you sign in"** so it starts automatically on future logins.

```bash
# Clone this repository
cd ~/Downloads
git clone https://github.com/ybroze/minibot.git

# Run the installer (creates dirs, copies scripts, configures shell,
# prompts for secrets, and builds the OpenClaw Docker image)
bash minibot/install.sh

# Load the new shell config
source ~/.zshrc
```

The installer will prompt you for each required secret (`POSTGRES_PASSWORD`,
`REDIS_PASSWORD`, `MONGO_PASSWORD`, `OPENCLAW_GATEWAY_PASSWORD`). These are
stored in the macOS Keychain — no plaintext `.env` files. OpenClaw manages its
own internal secrets (API keys, bot tokens) separately. The installer also
builds the `openclaw:local` Docker image from source — this takes a few minutes
on first run.

### 4b. Configure API Spending Limits

Before starting services that use external APIs (LLM providers, messaging
platforms, etc.), set spending limits on each provider's dashboard. The
keychain protects your keys at rest, but it can't prevent a runaway agent
from burning through credits at runtime.

For each API key you add:

1. Log in to the provider's billing or usage dashboard.
2. Set a **daily** and **monthly** spending cap.
3. Enable **email or webhook alerts** at 50% and 80% of those caps.
4. Where available, prefer **prepaid/credit-based** billing — it acts as a
   natural spending ceiling (you can't spend what you haven't loaded).

> **Note:** Configure each provider's spending limits *before* you start
> services. API keys for LLM providers and other external services are managed
> by OpenClaw internally — not through `minibot-secrets.sh`. The secrets
> stored in the macOS Keychain via `minibot-secrets.sh` are the infrastructure
> passwords (`POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `MONGO_PASSWORD`,
> `OPENCLAW_GATEWAY_PASSWORD`).

### 5. Start Services

```bash
# Start all services
~/minibot/bin/minibot-start.sh

# Check container status
docker compose -f ~/minibot/docker/docker-compose.yml ps

# Follow live logs
~/minibot/bin/minibot-logs.sh
```

**Note:** PostgreSQL, Redis, MongoDB, and OpenClaw run as Docker containers —
they are not installed on the host. If you need CLI tools for debugging
(e.g., `psql`, `redis-cli`, or `mongosh`), install them as the admin user:
`brew install libpq redis mongosh`.

#### Container Memory Allocation (16 GB Mac Mini)

| Service    | Container          | Memory Limit | CPU Limit | Notes                                  |
|------------|--------------------|-------------|-----------|----------------------------------------|
| PostgreSQL | minibot-postgres   | 1 GB        | 1.0       | Query caching, shared buffers          |
| Redis      | minibot-redis      | 256 MB      | 0.5       | Cache/message broker                   |
| MongoDB    | minibot-mongo      | 1 GB        | 1.0       | WiredTiger cache                       |
| OpenClaw   | minibot-openclaw   | 4 GB        | 2.0       | Node.js heap set to 3.5 GB via `NODE_OPTIONS` |
| **Total**  |                    | **6.25 GB** | **3.5**   |                                        |

macOS and Docker Desktop require approximately 4-5 GB, leaving 5-6 GB of free
headroom on a 16 GB machine. These limits are set via `deploy.resources.limits`
in `docker/docker-compose.yml`.

### 6. Enable 24/7 Operation

This is a dedicated machine that should run Minibot continuously. The
installer (Step 4) already installed the LaunchAgent. Verify it's loaded:

```bash
launchctl list | grep minibot
```

If it's missing, install it manually:

```bash
~/minibot/scripts/install-launchagent.sh
```

Then configure the machine for unattended operation:

1. **Prevent sleep:** If you ran `admin-setup.sh`, sleep is already disabled
via `pmset`. Otherwise: System Settings > Energy > Prevent automatic sleeping
when the display is off > **ON**, and set "Turn display off after" to "Never."
2. **Enable auto-login:**
System Settings > Users & Groups > Automatic login > select the `minibot` user.
Without this, the LaunchAgent won't start after a reboot until someone logs in.

> **Note on FileVault + auto-login:** macOS disables the auto-login option in
> System Settings when FileVault is enabled. If you followed the hardening steps
> above, you will see this option greyed out. In that case, after every reboot
> you must initiate the `minibot` user session manually — either by connecting
> via Screen Sharing (`System Settings > General > Sharing > Screen Sharing`)
> from another device on your Tailscale network, or by logging in at the
> physical keyboard. Once the `minibot` session starts, the LaunchAgent fires
> automatically and services come up.

**Note:** If auto-login is enabled (only possible without FileVault), the
system recovers fully automatically after a reboot — the `minibot` session
starts and the LaunchAgent fires with no intervention. With FileVault enabled,
you must initiate the `minibot` session after each reboot as described above,
after which services come up automatically.

Test by rebooting:

```bash
sudo reboot
```

After the reboot, if FileVault is enabled you must unlock the disk first.
Reconnect via SSH — you will see the pre-boot prompt — and authenticate
with the admin password. Then connect again (or use Screen Sharing) to
start the `minibot` session. Once logged in as `minibot`, verify services
came back:

```bash
mb-status
```

## Directory Structure

After running the installer, you'll have:

```
~/minibot/
├── bin/                    # User scripts
│   ├── minibot-start.sh
│   ├── minibot-stop.sh
│   ├── minibot-logs.sh
│   └── minibot-secrets.sh
├── data/                   # Persistent data (700 permissions)
│   ├── postgres/
│   ├── redis/
│   ├── mongo/
│   ├── openclaw/
│   └── logs/system/        # LaunchAgent stdout/stderr logs
├── docker/                 # Docker configs
│   └── docker-compose.yml
├── vendor/                 # Third-party source (created by build-openclaw.sh)
│   └── openclaw/
├── scripts/                # Maintenance scripts
│   ├── admin-setup.sh
│   ├── build-openclaw.sh
│   ├── backup.sh
│   ├── restore.sh
│   ├── health-check.sh
│   ├── security-audit.sh
│   ├── reset.sh
│   ├── install-launchagent.sh
│   └── uninstall-launchagent.sh
├── docs/                   # Documentation
│   ├── emergency.md
│   ├── filesystem.md
│   ├── maintenance.md
│   ├── networking.md
│   ├── secrets.md
│   ├── security.md
│   └── threat-model.md
└── zshrc-additions.sh      # Shell config (sourced by ~/.zshrc)
```

The repository also includes `install.sh`, `setup-minibot-dirs.sh`, and
`misc/openclaw-setup-guide.md` (a detailed walkthrough of OpenClaw
configuration including models, Telegram, sandbox, and SOUL.md).

## Available Scripts

### Operational Scripts (in `~/minibot/bin/`)

- **minibot-start.sh** - Start all services (loads secrets from Keychain
    automatically)
- **minibot-stop.sh** - Stop all services
- **minibot-logs.sh** - View logs (optionally pass service name)
- **minibot-secrets.sh** - Manage secrets in the macOS Keychain

### Maintenance Scripts (in `~/minibot/scripts/`)

- **admin-setup.sh** - One-time machine setup (run as admin before install.sh)
- **build-openclaw.sh** - Build the OpenClaw Docker image from source
- **backup.sh** - Backup data and configuration
- **restore.sh** - Restore from a backup
- **health-check.sh** - Check system health and status
- **security-audit.sh** - Audit security posture (ports, permissions, secrets)
- **reset.sh** - Nuclear option: reset everything (destructive!)
- **install-launchagent.sh** - Start Minibot automatically on login
- **uninstall-launchagent.sh** - Remove the LaunchAgent

## Documentation (in `~/minibot/docs/`)

- Threat model: `docs/threat-model.md`
- Emergency procedures: `docs/emergency.md`
- Maintenance guide: `docs/maintenance.md`
- Containerization security: `docs/security.md`
- Networking & ports: `docs/networking.md`
- Secrets management: `docs/secrets.md`
- Filesystem security: `docs/filesystem.md`
- OpenClaw setup guide: `misc/openclaw-setup-guide.md`

## Shell Aliases

The following aliases are available after sourcing `~/.zshrc`:

| Alias | Description |
|-------|-------------|
| `mb-build` | Build the OpenClaw Docker image from source |
| `mb-start` | Start all services |
| `mb-stop` | Stop all services |
| `mb-logs` | View Docker logs (optionally pass service name) |
| `mb-status` | Show container status |
| `mb-secrets` | Manage Keychain secrets |
| `mb-health` | Run health check |
| `mb-audit` | Run security audit |

## Common Tasks

### View Service Status
```bash
docker compose -f ~/minibot/docker/docker-compose.yml ps
# Or use the alias:
mb-status
```

### Manage Secrets
```bash
# First-time setup (interactive prompts)
mb-secrets init

# Set or update a secret
mb-secrets set POSTGRES_PASSWORD

# View which secrets are stored
mb-secrets list

# Retrieve a secret value
mb-secrets get POSTGRES_PASSWORD
```

### Follow Logs for a Specific Service
```bash
~/minibot/bin/minibot-logs.sh postgres
~/minibot/bin/minibot-logs.sh redis
~/minibot/bin/minibot-logs.sh mongo
~/minibot/bin/minibot-logs.sh openclaw
```

### Create a Backup
```bash
~/minibot/scripts/backup.sh
```

### Restore from Backup
```bash
~/minibot/scripts/restore.sh ~/minibot-backups/20260212-143022
```

### Check System Health
```bash
~/minibot/scripts/health-check.sh
```

### Reset Everything
```bash
~/minibot/scripts/reset.sh
# WARNING: This deletes all data!
```

### Access Minibot Remotely (via Tailscale)
```bash
# Check your Mac Mini's Tailscale IP
tailscale ip -4

# From any device on your tailnet, connect using that IP:
#   ssh minibot@100.x.x.x
#   Or forward a port: ssh -L 5432:127.0.0.1:5432 minibot@100.x.x.x
```

### Manage the LaunchAgent (24/7 Operation)
```bash
# Check if the LaunchAgent is installed and loaded
launchctl list | grep minibot

# Install (or reinstall)
~/minibot/scripts/install-launchagent.sh

# Remove
~/minibot/scripts/uninstall-launchagent.sh

# View LaunchAgent logs
tail -f ~/minibot/data/logs/system/launchagent-stderr.log
```


## Environment Cleanup

Optional to do, but useful for either the admin or the `minibot` user.

> **Note:** If you accepted the account-hardening prompt in `install.sh`
> (Step 8), the App Store update step below is already done.

### Removable macOS Apps

For a dedicated OpenClaw machine, you can remove these apps:

**Media & Entertainment:**
- Music, TV, Podcasts, News, Books

**Social & Communication:**
- FaceTime, Messages (keep if using 2FA), Mail, Contacts, Calendar

**Productivity:**
- Keynote, Pages, Numbers, Freeform, Reminders, Home, Stocks, Weather, Voice Memos, Photo Booth

**Keep:**
- Safari, Terminal, System Settings, App Store, Finder

To remove apps, drag them from `/Applications` to the Trash. Some system apps
are protected by SIP and cannot be removed — just ignore those.

### Disable Background Services

Run the following as the **admin user** (requires `sudo`):

```bash
# Disable Spotlight indexing for the data directory
sudo mdutil -i off ~/minibot/data
```

Run the following as the `minibot` user:

```bash
# Disable automatic App Store updates
defaults write com.apple.commerce AutoUpdate -bool false
```

## Troubleshooting

### Docker not starting
```bash
# Launch Docker Desktop
open -a Docker
```

Wait 30–60 seconds for the whale icon in the menu bar to stop animating
before retrying — the daemon takes a moment to fully initialize.

```bash
~/minibot/bin/minibot-start.sh
```

### Keychain secrets missing
If `mb-start` reports `Error: POSTGRES_PASSWORD not found in keychain`:
```bash
# Run interactive first-time secrets setup
mb-secrets init

# Verify secrets are stored
mb-secrets list
```

### OpenClaw won't start
```bash
# Check if the image exists (if not, run mb-build first)
docker image inspect openclaw:local

# Check OpenClaw logs for startup errors
mb-logs openclaw

# OpenClaw waits for Postgres and Redis to be healthy — check their status
mb-status
```

### Database connection errors
```bash
# Check PostgreSQL logs
docker logs minibot-postgres

# Verify password is stored in keychain
mb-secrets get POSTGRES_PASSWORD
```

### Disk space issues
```bash
# Check disk usage
du -sh ~/minibot/data/*

# Remove stopped containers and dangling images (safe)
docker system prune

# Remove ALL unused images including openclaw:local (requires mb-build to recover)
# docker system prune -a
```

---

**Created:** February 2026
**For:** Minibot macOS Dedicated-Hardware Environment
