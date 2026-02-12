# OpenClaw macOS Environment Setup Guide

## Part 1: macOS User-Level Environment Segregation

### Creating a Dedicated `openclaw` User

```bash
# 1. Create the user account via System Settings or command line
# Via GUI: System Settings > Users & Groups > Add Account...
# - Account type: Standard
# - Full name: OpenClaw Experiments
# - Account name: openclaw
# - Password: [your choice]

# Via command line (requires admin):
sudo sysadminctl -addUser openclaw -fullName "OpenClaw Experiments" -password -admin
# Note: Omit -admin flag if you want a standard (non-admin) user
```

### User Account Configuration

```bash
# After creating the user, log into the openclaw account and:

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
# OpenClaw Experimental Environment
export OPENCLAW_HOME="$HOME/openclaw"
export PATH="$OPENCLAW_HOME/bin:$HOME/.local/bin:$PATH"

# Prevent accidental system modifications
export HOMEBREW_NO_AUTO_UPDATE=1

# Clear environment of user-specific cruft
unset HISTFILE  # Optional: disable shell history

# Prompt indicator
export PS1="%F{cyan}[openclaw]%f %~ %# "
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
sudo mdutil -i off /Users/openclaw/openclaw/data

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

## Part 3: OpenClaw Directory Structure

### Recommended Directory Layout

```
/Users/openclaw/
├── openclaw/                          # Main OpenClaw installation root
│   ├── bin/                           # User scripts, utilities
│   │   ├── openclaw-start.sh
│   │   ├── openclaw-stop.sh
│   │   └── openclaw-logs.sh
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
│   │   └── openclaw.yaml              # Main config
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
│   ├── agents/                        # Agent source code
│   │   ├── agent-template/
│   │   ├── custom-agent-1/
│   │   └── custom-agent-2/
│   ├── lib/                           # Shared libraries
│   │   ├── python/
│   │   └── node/
│   ├── scripts/                       # Maintenance & utility scripts
│   │   ├── backup.sh
│   │   ├── restore.sh
│   │   └── health-check.sh
│   ├── experiments/                   # Experimental setups
│   │   ├── 2025-02-12-multi-agent/
│   │   ├── 2025-02-13-failure-modes/
│   │   └── README.md
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
# setup-openclaw-dirs.sh

BASE_DIR="$HOME/openclaw"

# Create main directories
mkdir -p "$BASE_DIR"/{bin,config,data,docker,agents,lib,scripts,experiments,docs,tmp}

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

echo "OpenClaw directory structure created at: $BASE_DIR"
```

### Initial Configuration Templates

#### `~/openclaw/docker/docker-compose.yml`

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: openclaw-postgres
    environment:
      POSTGRES_DB: openclaw
      POSTGRES_USER: openclaw
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-changeme}
    volumes:
      - ../data/postgres:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - openclaw-net

  redis:
    image: redis:7-alpine
    container_name: openclaw-redis
    volumes:
      - ../data/redis:/data
    ports:
      - "6379:6379"
    networks:
      - openclaw-net

  # OpenClaw orchestrator (placeholder - adjust based on actual OpenClaw setup)
  orchestrator:
    build:
      context: ../
      dockerfile: docker/Dockerfiles/orchestrator.Dockerfile
    container_name: openclaw-orchestrator
    depends_on:
      - postgres
      - redis
    volumes:
      - ../config:/app/config:ro
      - ../data/logs:/app/logs
    environment:
      - DATABASE_URL=postgresql://openclaw:${POSTGRES_PASSWORD:-changeme}@postgres:5432/openclaw
      - REDIS_URL=redis://redis:6379
    networks:
      - openclaw-net

networks:
  openclaw-net:
    driver: bridge
```

#### `~/openclaw/bin/openclaw-start.sh`

```bash
#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "Starting OpenClaw services..."
docker-compose -f docker/docker-compose.yml up -d

echo "Services started. Check status with: docker-compose -f docker/docker-compose.yml ps"
```

#### `~/openclaw/bin/openclaw-stop.sh`

```bash
#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "Stopping OpenClaw services..."
docker-compose -f docker/docker-compose.yml down

echo "Services stopped."
```

#### `~/openclaw/bin/openclaw-logs.sh`

```bash
#!/bin/bash
cd "$(dirname "$0")/.."

# Follow logs for all services
docker-compose -f docker/docker-compose.yml logs -f "$@"
```

### Make Scripts Executable

```bash
chmod +x ~/openclaw/bin/*.sh
```

---

## Part 4: Development Environment Setup

### Install Homebrew (as openclaw user)

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

# Create virtual environment for OpenClaw
cd ~/openclaw
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
# 1. Create openclaw user (System Settings)
# 2. Log in as openclaw user
# 3. Run initial setup
curl -O [this-script-url] && bash setup-openclaw-dirs.sh

# 4. Install Homebrew + dependencies
# (see Part 4)

# 5. Clone OpenClaw (adjust URL)
cd ~/openclaw
git clone https://github.com/openclaw/openclaw.git src
# Or download and extract to src/

# 6. Configure
cp config/environments/dev.env.example config/environments/dev.env
# Edit config files as needed

# 7. Start services
~/openclaw/bin/openclaw-start.sh

# 8. Verify
docker ps
curl http://localhost:8080/health  # Adjust port based on actual setup
```

---

## Part 6: Maintenance

### Backup

```bash
#!/bin/bash
# ~/openclaw/scripts/backup.sh

BACKUP_DIR="$HOME/openclaw-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Stop services
~/openclaw/bin/openclaw-stop.sh

# Backup data
cp -r ~/openclaw/data "$BACKUP_DIR/"
cp -r ~/openclaw/config "$BACKUP_DIR/"

# Restart services
~/openclaw/bin/openclaw-start.sh

echo "Backup created at: $BACKUP_DIR"
```

### Reset Environment

```bash
# Nuclear option: completely reset
~/openclaw/bin/openclaw-stop.sh
rm -rf ~/openclaw/data/*
docker-compose -f ~/openclaw/docker/docker-compose.yml down -v
# Recreate from scratch
```

---

## Notes

- This setup assumes you're using OpenClaw from source or a distribution that supports Docker
- Adjust paths and configurations based on actual OpenClaw documentation
- The directory structure follows XDG Base Directory conventions where appropriate
- Consider setting up log rotation for `~/openclaw/data/logs/`
- Use version control (git) for `~/openclaw/config/` and `~/openclaw/experiments/`

