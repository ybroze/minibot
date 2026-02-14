# Minibot macOS Environment Setup Guide

## Part 0: Initial Machine Hardening

Before creating the dedicated user, secure the base system. These steps only
need to be done once per machine and require an admin account.

### Enable FileVault (Full-Disk Encryption)

```bash
# System Settings > Privacy & Security > FileVault > Turn On
# CRITICAL: Save the recovery key in a password manager or print it.
# Without FileVault, anyone with physical access to the machine can
# read all data, including keychain secrets, by booting into recovery mode.
```

### Enable the macOS Firewall

```bash
# System Settings > Network > Firewall > Turn On
# This prevents unsolicited inbound connections.
# Alternatively, via command line:
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
```

### Install Xcode Command Line Tools

```bash
# Required by Homebrew, Git, and many build tools.
xcode-select --install
# A popup appears — click "Install" and wait for it to complete.
```

## Part 1: macOS User-Level Environment Segregation

### Creating a Dedicated `minibot` User

```bash
# 1. Create the user account via System Settings or command line
# Via GUI: System Settings > Users & Groups > Add Account...
# - Account type: Standard
# - Full name: Minibot Experiments
# - Account name: minibot
# - Password: [your choice]

# Via command line (requires admin):
sudo sysadminctl -addUser minibot -fullName "Minibot Experiments" -password -admin
# Note: Omit -admin flag if you want a standard (non-admin) user
```

### User Account Configuration

```bash
# After creating the user, log into the minibot account and:

# 1. Disable iCloud integration
# System Settings > Apple ID > iCloud > Turn off all sync services

# 2. Disable Siri
# System Settings > Siri & Spotlight > Disable "Ask Siri"

# 3. Disable location services (optional)
# System Settings > Privacy & Security > Location Services > Off

# 4. Minimal dock setup
# Remove all default applications from dock except:
# - Finder
# - Terminal (or iTerm2)
# - System Settings
```

### Environment Isolation Best Practices

```bash
# Set shell to zsh explicitly (should be default on modern macOS)
chsh -s /bin/zsh

# Create isolated shell profile
cat > ~/.zshrc << 'EOF'
# Minibot Experimental Environment
export MINIBOT_HOME="$HOME/minibot"
export PATH="$MINIBOT_HOME/bin:$HOME/.local/bin:$PATH"

# Prevent accidental system modifications
export HOMEBREW_NO_AUTO_UPDATE=1

# Clear environment of user-specific cruft
unset HISTFILE  # Optional: disable shell history

# Prompt indicator
export PS1="%F{cyan}[minibot]%f %~ %# "
EOF

source ~/.zshrc
```

---

## Part 2: Removing Extraneous Pre-Installed Software

### Apple Apps That Can Be Removed (macOS Sonoma+)

**Safe to remove for a dedicated server/experimentation machine:**

```bash
# Navigate to /Applications and move these to Trash:
# (Some require disabling SIP - not recommended unless you know what you're doing)

# Media & Entertainment
# - Music.app
# - TV.app
# - Podcasts.app
# - News.app
# - Books.app

# Social & Communication
# - FaceTime.app
# - Messages.app (keep if you use 2FA via SMS)
# - Mail.app (if not needed)
# - Contacts.app
# - Calendar.app

# Productivity (be selective)
# - Keynote.app
# - Pages.app
# - Numbers.app
# - Freeform.app
# - Notes.app (might want to keep for quick notes)
# - Reminders.app
# - Home.app
# - Stocks.app
# - Weather.app
# - Voice Memos.app
# - Photo Booth.app

# Keep these:
# - Safari (needed for OAuth flows, documentation)
# - Terminal.app
# - System Settings
# - App Store (for updates)
# - Finder
```

### Removal via Command Line (CAREFUL!)

```bash
# BACKUP FIRST! Some apps are protected by SIP.
# This approach works for user-installable apps:

# Example: Remove GarageBand (if installed)
sudo rm -rf /Applications/GarageBand.app

# For system apps, you may need to disable SIP (not recommended for production)
# Better approach: Just hide them from Launchpad
```

### Disable Background Services

```bash
# Disable Spotlight indexing for specific directories
sudo mdutil -i off /Users/minibot/minibot/data

# Disable automatic updates for Mac App Store apps
defaults write com.apple.commerce AutoUpdate -bool false

# Disable Gatekeeper (optional, allows unsigned apps)
# sudo spctl --master-disable  # Use with caution
```

### Clean Up Default Directories

```bash
# Remove or minimize default user directories
cd ~
rm -rf Movies/ Music/ Public/

# Keep these (or symlink to /tmp if you want to minimize clutter):
# - Desktop/
# - Documents/
# - Downloads/
```

---

## Part 3: Minibot Directory Structure

### Recommended Directory Layout

```
/Users/minibot/
├── minibot/                           # Main Minibot installation root
│   ├── bin/                           # User scripts, utilities
│   │   ├── minibot-start.sh
│   │   ├── minibot-stop.sh
│   │   └── minibot-logs.sh
│   ├── config/                        # Configuration files
│   │   ├── agents/                    # Agent definitions
│   │   │   ├── agent-1.yaml
│   │   │   └── agent-2.yaml
│   │   ├── orchestration/             # Orchestration rules
│   │   │   └── routing.yaml
│   │   ├── environments/              # Environment-specific configs
│   │   │   ├── dev.env
│   │   │   ├── staging.env
│   │   │   └── prod.env
│   │   └── minibot.yaml               # Main config
│   ├── data/                          # Persistent data
│   │   ├── postgres/                  # Database files
│   │   ├── redis/                     # Redis persistence
│   │   └── logs/                      # Application logs
│   │       ├── agents/
│   │       ├── orchestrator/
│   │       └── system/
│   ├── docker/                        # Docker configurations
│   │   ├── docker-compose.yml
│   │   ├── docker-compose.dev.yml
│   │   └── Dockerfiles/
│   │       ├── agent.Dockerfile
│   │       └── orchestrator.Dockerfile
│   ├── lib/                           # Shared libraries
│   │   ├── python/
│   │   └── node/
│   ├── scripts/                       # Maintenance & utility scripts
│   │   ├── backup.sh
│   │   ├── restore.sh
│   │   └── health-check.sh
│   ├── docs/                          # Local documentation
│   │   ├── architecture.md
│   │   ├── agent-development.md
│   │   └── troubleshooting.md
│   └── tmp/                           # Temporary files
│       └── .gitkeep
├── .config/                           # XDG config dir (optional)
├── .cache/                            # Cache directory
└── .local/                            # Local installations
    ├── bin/
    └── lib/
```

### Directory Creation Script

```bash
#!/bin/bash
# setup-minibot-dirs.sh

BASE_DIR="$HOME/minibot"

# Create main directories
mkdir -p "$BASE_DIR"/{bin,config,data,docker,agents,lib,scripts,docs,tmp}

# Config subdirectories
mkdir -p "$BASE_DIR/config"/{agents,orchestration,environments}

# Data subdirectories
mkdir -p "$BASE_DIR/data"/{postgres,redis,logs/{agents,orchestrator,system}}

# Docker subdirectories
mkdir -p "$BASE_DIR/docker/Dockerfiles"

# Lib subdirectories
mkdir -p "$BASE_DIR/lib"/{python,node}

# Standard hidden directories
mkdir -p "$HOME/.config" "$HOME/.cache" "$HOME/.local"/{bin,lib}

# Create .gitkeep files for empty directories
find "$BASE_DIR" -type d -empty -exec touch {}/.gitkeep \;

# Set up basic .gitignore
cat > "$BASE_DIR/.gitignore" << 'EOF'
# Data & logs
data/
tmp/
*.log

# Environment files
*.env
!*.env.example

# IDE
.vscode/
.idea/

# OS
.DS_Store
EOF

echo "Minibot directory structure created at: $BASE_DIR"
```

### Initial Configuration Templates

#### `~/minibot/docker/docker-compose.yml`

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: minibot-postgres
    environment:
      POSTGRES_DB: minibot
      POSTGRES_USER: minibot
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-changeme}
    volumes:
      - ../data/postgres:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - minibot-net

  redis:
    image: redis:7-alpine
    container_name: minibot-redis
    volumes:
      - ../data/redis:/data
    ports:
      - "6379:6379"
    networks:
      - minibot-net

  # Agent orchestrator (placeholder - adjust based on actual setup)
  orchestrator:
    build:
      context: ../
      dockerfile: docker/Dockerfiles/orchestrator.Dockerfile
    container_name: minibot-orchestrator
    depends_on:
      - postgres
      - redis
    volumes:
      - ../config:/app/config:ro
      - ../data/logs:/app/logs
    environment:
      - DATABASE_URL=postgresql://minibot:${POSTGRES_PASSWORD:-changeme}@postgres:5432/minibot
      - REDIS_URL=redis://redis:6379
    networks:
      - minibot-net

networks:
  minibot-net:
    driver: bridge
```

#### `~/minibot/bin/minibot-start.sh`

```bash
#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "Starting Minibot services..."
docker-compose -f docker/docker-compose.yml up -d

echo "Services started. Check status with: docker-compose -f docker/docker-compose.yml ps"
```

#### `~/minibot/bin/minibot-stop.sh`

```bash
#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "Stopping Minibot services..."
docker-compose -f docker/docker-compose.yml down

echo "Services stopped."
```

#### `~/minibot/bin/minibot-logs.sh`

```bash
#!/bin/bash
cd "$(dirname "$0")/.."

# Follow logs for all services
docker-compose -f docker/docker-compose.yml logs -f "$@"
```

### Make Scripts Executable

```bash
chmod +x ~/minibot/bin/*.sh
```

---

## Part 4: Development Environment Setup

### Install Homebrew (as minibot user)

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to PATH (should be in ~/.zprofile automatically)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### Install Core Dependencies

```bash
# Essential tools
brew install git docker docker-compose python@3.11 node@20 postgresql@15

# Development tools
brew install --cask visual-studio-code iterm2

# Utilities
brew install jq yq tree htop
```

### Python Environment

```bash
# Install pyenv for version management
brew install pyenv

# Add to shell
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init -)"' >> ~/.zshrc

# Install Python 3.11
pyenv install 3.11.7
pyenv global 3.11.7

# Create virtual environment for Minibot
cd ~/minibot
python -m venv venv
source venv/bin/activate
pip install --upgrade pip setuptools wheel
```

### Node Environment

```bash
# Set up nvm (Node Version Manager) - optional
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Or just use Homebrew's Node
node --version
npm --version
```

---

## Part 5: Quick Start Checklist

```bash
# 1. Create minibot user (System Settings)
# 2. Log in as minibot user
# 3. Run initial setup
curl -O [this-script-url] && bash setup-minibot-dirs.sh

# 4. Install Homebrew + dependencies
# (see Part 4)

# 5. Set up your agent code/configuration
cd ~/minibot
# Add your agent implementations, configs, etc.

# 6. Configure environment
cp docker/.env.example docker/.env
# Edit .env file with your settings

# 7. Start services
~/minibot/bin/minibot-start.sh

# 8. Verify
docker ps
curl http://localhost:8080/health  # Adjust port based on actual setup
```

---

## Part 6: Maintenance

### Backup

```bash
#!/bin/bash
# ~/minibot/scripts/backup.sh

BACKUP_DIR="$HOME/minibot-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Stop services
~/minibot/bin/minibot-stop.sh

# Backup data
cp -r ~/minibot/data "$BACKUP_DIR/"
cp -r ~/minibot/config "$BACKUP_DIR/"

# Restart services
~/minibot/bin/minibot-start.sh

echo "Backup created at: $BACKUP_DIR"
```

### Reset Environment

```bash
# Nuclear option: completely reset
~/minibot/bin/minibot-stop.sh
rm -rf ~/minibot/data/*
docker compose -f ~/minibot/docker/docker-compose.yml down -v
# Recreate from scratch
```

---

## Part 7: Remote Access

If you need to access the Minibot machine remotely (e.g., from a laptop or
phone), **never expose Docker ports to the public internet.** All ports in the
`docker-compose.yml` are bound to `127.0.0.1` for this reason.

### Recommended: Tailscale

Tailscale creates a private mesh VPN between your devices. Install it on both
the Minibot machine and your remote device:

```bash
brew install --cask tailscale
# Open Tailscale from Applications and log in.
# Install Tailscale on your phone/laptop and log in with the same account.
# Access the machine via its Tailscale IP (100.x.x.x).
```

### Alternative: SSH Tunnel

If you prefer not to use Tailscale, you can SSH into the machine and forward
ports locally:

```bash
# From your remote machine, forward Postgres:
ssh -L 5432:127.0.0.1:5432 minibot@<machine-ip>

# Or forward multiple ports:
ssh -L 5432:127.0.0.1:5432 -L 6379:127.0.0.1:6379 minibot@<machine-ip>
```

---

## Notes

- This setup creates an isolated environment for agent experimentation
- The directory structure follows XDG Base Directory conventions where appropriate
- Consider setting up log rotation for `~/minibot/data/logs/`
- Use version control (git) for `~/minibot/config/`
- Adjust configurations based on your specific agent implementations and requirements
- All secrets are stored in the macOS Keychain — see `minibot-secrets.sh` for management
- Never bind Docker ports to `0.0.0.0` — use `127.0.0.1` and access remotely via Tailscale or SSH

