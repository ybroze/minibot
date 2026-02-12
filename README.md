# OpenClaw macOS Setup Scripts

This repository contains all the scripts and configuration files needed to set up a clean, isolated OpenClaw experimentation environment on macOS.

## Quick Start

### 1. Create the `openclaw` User

Via System Settings:
- Go to **System Settings > Users & Groups**
- Click the lock icon to make changes
- Click **Add Account...**
- Select **Standard** account type
- Full name: `OpenClaw Experiments`
- Account name: `openclaw`
- Set a password

### 2. Log in as `openclaw` User

Log out of your current account and log in as the `openclaw` user.

### 3. Run the Setup Script

```bash
# Clone or download this repository
cd ~/Downloads
# (extract the openclaw-setup files here)

# Run the directory setup script
bash openclaw-setup/setup-openclaw-dirs.sh

# Copy the scripts to the appropriate locations
cp -r openclaw-setup/bin/* ~/openclaw/bin/
cp -r openclaw-setup/docker/* ~/openclaw/docker/
cp -r openclaw-setup/scripts/* ~/openclaw/scripts/

# Make scripts executable
chmod +x ~/openclaw/bin/*.sh
chmod +x ~/openclaw/scripts/*.sh
```

### 4. Configure Shell Environment

```bash
# Add the shell configuration
cat openclaw-setup/zshrc-additions.sh >> ~/.zshrc
source ~/.zshrc
```

### 5. Install Dependencies

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install core dependencies
brew install git docker docker-compose python@3.11 node@20
brew install --cask visual-studio-code iterm2
brew install jq yq tree htop
```

### 6. Configure Docker Environment

```bash
# Copy and edit the environment file
cd ~/openclaw/docker
cp .env.example .env
# Edit .env and set POSTGRES_PASSWORD
```

### 7. Start Services

```bash
# Start the base infrastructure
~/openclaw/bin/openclaw-start.sh

# Check status
~/openclaw/bin/openclaw-logs.sh
```

## Directory Structure

After running the setup script, you'll have:

```
~/openclaw/
├── bin/                    # User scripts
│   ├── openclaw-start.sh
│   ├── openclaw-stop.sh
│   └── openclaw-logs.sh
├── config/                 # Configuration files
│   ├── agents/
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
│   └── reset.sh
├── experiments/            # Experimental setups
├── docs/                   # Documentation
└── tmp/                    # Temporary files
```

## Available Scripts

### Operational Scripts (in `~/openclaw/bin/`)

- **openclaw-start.sh** - Start all services
- **openclaw-stop.sh** - Stop all services
- **openclaw-logs.sh** - View logs (optionally pass service name)

### Maintenance Scripts (in `~/openclaw/scripts/`)

- **backup.sh** - Backup data and configuration
- **restore.sh** - Restore from a backup
- **health-check.sh** - Check system health and status
- **reset.sh** - Nuclear option: reset everything (destructive!)

## Common Tasks

### View Service Status
```bash
docker-compose -f ~/openclaw/docker/docker-compose.yml ps
# Or use the alias:
oc-status
```

### Follow Logs for a Specific Service
```bash
~/openclaw/bin/openclaw-logs.sh postgres
~/openclaw/bin/openclaw-logs.sh redis
```

### Create a Backup
```bash
~/openclaw/scripts/backup.sh
```

### Restore from Backup
```bash
~/openclaw/scripts/restore.sh ~/openclaw-backups/20250212-143022
```

### Check System Health
```bash
~/openclaw/scripts/health-check.sh
```

### Reset Everything
```bash
~/openclaw/scripts/reset.sh
# WARNING: This deletes all data!
```

## Shell Aliases

The following aliases are available after sourcing `~/.zshrc`:

- `oc-start` - Start services
- `oc-stop` - Stop services
- `oc-logs` - View logs
- `oc-status` - Check container status

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
sudo mdutil -i off ~/openclaw/data

# Disable automatic App Store updates
defaults write com.apple.commerce AutoUpdate -bool false
```

## Next Steps

1. Install the actual OpenClaw software (follow their documentation)
2. Configure your first agent in `~/openclaw/config/agents/`
3. Start experimenting with multi-agent setups in `~/openclaw/experiments/`
4. Version control your configurations with git

## Troubleshooting

### Docker not starting
```bash
# Check if Docker Desktop is running
open -a Docker

# Wait for Docker to fully start, then retry
~/openclaw/bin/openclaw-start.sh
```

### Database connection errors
```bash
# Check PostgreSQL logs
docker logs openclaw-postgres

# Verify password in .env matches docker-compose.yml
```

### Disk space issues
```bash
# Check disk usage
du -sh ~/openclaw/data/*

# Clean old Docker images
docker system prune -a
```

## Version Control

It's recommended to track your configuration in git:

```bash
cd ~/openclaw
git init
git add config/ experiments/ docker/docker-compose.yml
git commit -m "Initial OpenClaw configuration"
```

Note: The `.gitignore` file automatically excludes data, logs, and sensitive files.

## Support

- OpenClaw Documentation: [openclaw.ai](https://openclaw.ai)
- This setup is based on the comprehensive guide in `openclaw-macos-setup.md`

---

**Created:** February 2025  
**For:** OpenClaw macOS Experimentation Environment
