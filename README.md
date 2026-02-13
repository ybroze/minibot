# Minibot macOS Setup Scripts

This repository contains all the scripts and configuration files needed to set up a clean, isolated Minibot experimentation environment on macOS.

## Quick Start

### 1. Create the `minibot` User

Via System Settings:
- Go to **System Settings > Users & Groups**
- Click **Add Account...**
- Select **Standard** account type
- Full name: `Minibot Experiments`
- Account name: `minibot`
- Set a password

### 2. Log in as `minibot` User

Log out of your current account and log in as the `minibot` user.

### 3. Run the Setup Script

```bash
# Clone or download this repository
cd ~/Downloads
# (extract the minibot files here)

# Run the directory setup script
bash minibot/setup-minibot-dirs.sh

# Copy the scripts to the appropriate locations
cp -r minibot/bin/* ~/minibot/bin/
cp -r minibot/docker/* ~/minibot/docker/
cp -r minibot/scripts/* ~/minibot/scripts/

# Make scripts executable
chmod +x ~/minibot/bin/*.sh
chmod +x ~/minibot/scripts/*.sh
```

### 4. Configure Shell Environment

```bash
# Add the shell configuration
cat minibot/zshrc-additions.sh >> ~/.zshrc
source ~/.zshrc
```

### 5. Install Dependencies

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
brew install git python@3.11 node@20
brew install --cask visual-studio-code iterm2
brew install jq yq tree htop

# Install Tailscale for secure remote access (optional but recommended)
brew install --cask tailscale
```

### 5b. Set Up Tailscale (Optional)

Tailscale creates a private mesh VPN between your devices so you can reach
the Minibot machine remotely without exposing any ports to the internet.

1. Open Tailscale from Applications and log in (or create an account).
2. Install Tailscale on any device you want remote access from (phone, laptop, etc.) and log in with the same account.
3. Verify connectivity:
   ```bash
   tailscale status
   ```
   You should see all your devices listed with `100.x.x.x` addresses.

Once connected, you can reach the Minibot machine from any device on your
tailnet using its Tailscale IP — no port forwarding or firewall changes needed.

### 6. Store Secrets in the macOS Keychain

Minibot uses the macOS Keychain for secrets — no plaintext `.env` files.

```bash
# Interactive setup: prompts you for each required secret
~/minibot/bin/minibot-secrets.sh init

# Or set secrets individually
~/minibot/bin/minibot-secrets.sh set POSTGRES_PASSWORD
```

Secrets are stored in your login keychain under the service name `minibot`
and are loaded just-in-time when you start services.

### 6b. Configure API Spending Limits

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

> **Note:** The `REQUIRED_SECRETS` array in `minibot-secrets.sh` has commented
> placeholders for keys like `ANTHROPIC_API_KEY`. When you uncomment and store
> one, configure the provider's spending limits *before* you start services.

### 7. Start Services

```bash
# Start the base infrastructure
~/minibot/bin/minibot-start.sh

# Check status
~/minibot/bin/minibot-logs.sh
```

> **Note:** PostgreSQL and Redis run as Docker containers — they are not installed on the host. If you need CLI tools for debugging (e.g., `psql` or `redis-cli`), install them separately: `brew install libpq redis`.

### 8. Enable 24/7 Operation (Optional)

If this is a dedicated machine that should run Minibot continuously:

```bash
# Install the LaunchAgent
~/minibot/scripts/install-launchagent.sh

# Verify it's installed and loaded
launchctl list | grep minibot
```

Then configure the machine for unattended operation:

1. **Prevent sleep:** System Settings > Energy > Prevent automatic sleeping when the display is off > **ON**
2. **Enable auto-login** (for headless machines): System Settings > Users & Groups > Automatic login > select the `minibot` user. Without this, the LaunchAgent won't start after a reboot until someone logs in.

Test by rebooting:

```bash
sudo reboot

# After reboot, verify services came back:
mb-status
```

## Directory Structure

After running the setup script, you'll have:

```
~/minibot/
├── bin/                    # User scripts
│   ├── minibot-start.sh
│   ├── minibot-stop.sh
│   ├── minibot-logs.sh
│   └── minibot-secrets.sh
├── config/                 # Configuration files
│   ├── agents/
│   │   └── SOUL.md.example
│   ├── orchestration/
│   └── environments/
├── data/                   # Persistent data
│   ├── postgres/
│   ├── redis/
│   └── logs/
├── docker/                 # Docker configs
│   ├── docker-compose.yml
│   └── Dockerfiles/
├── agents/                 # Agent source code
├── lib/                    # Shared libraries
├── scripts/                # Maintenance scripts
│   ├── backup.sh
│   ├── restore.sh
│   ├── health-check.sh
│   ├── security-audit.sh
│   ├── reset.sh
│   ├── install-launchagent.sh
│   └── uninstall-launchagent.sh
├── docs/                   # Documentation
│   ├── threat-model.md
│   ├── emergency.md
│   └── maintenance.md
├── experiments/            # Experimental setups
└── tmp/                    # Temporary files
```

## Available Scripts

### Operational Scripts (in `~/minibot/bin/`)

- **minibot-start.sh** - Start all services (loads secrets from Keychain automatically)
- **minibot-stop.sh** - Stop all services
- **minibot-logs.sh** - View logs (optionally pass service name)
- **minibot-secrets.sh** - Manage secrets in the macOS Keychain

### Maintenance Scripts (in `~/minibot/scripts/`)

- **backup.sh** - Backup data and configuration
- **restore.sh** - Restore from a backup
- **health-check.sh** - Check system health and status
- **security-audit.sh** - Audit security posture (ports, permissions, secrets)
- **reset.sh** - Nuclear option: reset everything (destructive!)
- **install-launchagent.sh** - Start Minibot automatically on login
- **uninstall-launchagent.sh** - Remove the LaunchAgent

### Documentation (in `~/minibot/docs/`)

- **threat-model.md** - What Minibot defends against and residual risks
- **emergency.md** - What to do if you suspect compromise
- **maintenance.md** - Ongoing maintenance tasks and schedules

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
```

### Create a Backup
```bash
~/minibot/scripts/backup.sh
```

### Restore from Backup
```bash
~/minibot/scripts/restore.sh ~/minibot-backups/20250212-143022
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

## Shell Aliases

The following aliases are available after sourcing `~/.zshrc`:

- `mb-start` - Start services
- `mb-stop` - Stop services
- `mb-logs` - View logs
- `mb-status` - Check container status
- `mb-secrets` - Manage keychain secrets

## Environment Cleanup

### Removable macOS Apps

For a dedicated experimentation machine, you can remove these apps:

**Media & Entertainment:**
- Music, TV, Podcasts, News, Books

**Social & Communication:**
- FaceTime, Messages (keep if using 2FA), Mail, Contacts, Calendar

**Productivity:**
- Keynote, Pages, Numbers, Freeform, Reminders, Home, Stocks, Weather, Voice Memos, Photo Booth

**Keep:**
- Safari, Terminal, System Settings, App Store, Finder

### Disable Background Services

```bash
# Disable Spotlight indexing for data directory
sudo mdutil -i off ~/minibot/data

# Disable automatic App Store updates
defaults write com.apple.commerce AutoUpdate -bool false
```

## Next Steps

1. Add your agent implementations to `~/minibot/agents/`
2. Configure your agents in `~/minibot/config/agents/`
3. Set up orchestration rules in `~/minibot/config/orchestration/`
4. Start experimenting with multi-agent setups in `~/minibot/experiments/`
5. Version control your configurations with git

## Troubleshooting

### Docker not starting
```bash
# Check if Docker Desktop is running
open -a Docker

# Wait for Docker to fully start, then retry
~/minibot/bin/minibot-start.sh
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

# Clean old Docker images
docker system prune -a
```

## Version Control

It's recommended to track your configuration in git:

```bash
cd ~/minibot
git init
git add config/ experiments/ docker/docker-compose.yml
git commit -m "Initial Minibot configuration"
```

Note: The `.gitignore` file automatically excludes data, logs, and sensitive files.

## Maintenance

### Credential Rotation

Rotate secrets every 3 months (or immediately if you suspect compromise):

```bash
# 1. Set the new password in the keychain
mb-secrets set POSTGRES_PASSWORD

# 2. Recreate the containers so they pick up the new value
mb-stop
docker compose -f ~/minibot/docker/docker-compose.yml down -v
# WARNING: -v removes volumes. Back up first if you have data to keep.
mb-start
```

Repeat for `REDIS_PASSWORD` and any future secrets. When rotating an API
key for an external provider, it's also a good time to review your spending
limits on that provider's dashboard.

### Security Audit

Run the security audit script periodically:

```bash
~/minibot/scripts/security-audit.sh
```

### Restoring on a Fresh Machine

Backups (from `scripts/backup.sh`) contain data and config but **not secrets**.
After restoring on a new machine, you must re-initialize the keychain:

```bash
mb-secrets init
```

## File Permissions

Minibot uses the macOS Keychain for secrets, so there are no plaintext
passwords or API keys on disk. This is a deliberate improvement over the
common `.env` file pattern, where a single `cat` or stray backup can expose
everything.

For the files that *are* on disk, minibot takes a belt-and-suspenders approach:

- **`umask 077`** is set in the shell profile (`zshrc-additions.sh`), so every
  file the minibot user creates is owner-only (`rwx------`) by default. This
  prevents loose permissions from being created in the first place.
- **`config/`, `data/`, and `tmp/`** are set to `700` during install.
- **`security-audit.sh`** checks for permission drift, including world-readable
  files in `config/` and an incorrect umask.

**Known limitation — `docker inspect`:** Anyone with access to the Docker socket
on the host can run `docker inspect minibot-postgres` and see environment
variables (including `POSTGRES_PASSWORD`) in the container's config. This is a
Docker-wide issue with no clean fix short of Docker secrets (which require Swarm
mode). On a single-user dedicated machine this is low risk, but be aware that
Docker socket access is effectively root-equivalent.

**Known limitation — log file ownership:** Files created inside Docker volumes
may be owned by root or by the container's internal user, not the minibot host
user. The `data/` directory is `700`, which prevents other host users from
reading the logs, but the files inside may have looser permissions than
expected. The `security-audit.sh` script checks for this.

## Additional Resources

- Comprehensive setup guide: `docs/minibot-macos-setup.md`
- Threat model: `docs/threat-model.md`
- Emergency procedures: `docs/emergency.md`
- Maintenance guide: `docs/maintenance.md`
- Agent identity template: `config/agents/SOUL.md.example`

---

**Created:** February 2025  
**For:** Minibot macOS Experimentation Environment
