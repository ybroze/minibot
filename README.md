# Minibot macOS Setup Scripts

This repository contains all the scripts and configuration files needed to set up a clean, isolated Minibot experimentation environment on macOS.

## Quick Start

### 1. Create the `minibot` User

Via System Settings:
- Go to **System Settings > Users & Groups**
- Click the lock icon to make changes
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
cd ~/minibot/docker
cp .env.example .env
# Edit .env and set POSTGRES_PASSWORD
```

### 7. Start Services

```bash
# Start the base infrastructure
~/minibot/bin/minibot-start.sh

# Check status
~/minibot/bin/minibot-logs.sh
```

## Directory Structure

After running the setup script, you'll have:

```
~/minibot/
├── bin/                    # User scripts
│   ├── minibot-start.sh
│   ├── minibot-stop.sh
│   └── minibot-logs.sh
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

### Operational Scripts (in `~/minibot/bin/`)

- **minibot-start.sh** - Start all services
- **minibot-stop.sh** - Stop all services
- **minibot-logs.sh** - View logs (optionally pass service name)

### Maintenance Scripts (in `~/minibot/scripts/`)

- **backup.sh** - Backup data and configuration
- **restore.sh** - Restore from a backup
- **health-check.sh** - Check system health and status
- **reset.sh** - Nuclear option: reset everything (destructive!)

## Common Tasks

### View Service Status
```bash
docker-compose -f ~/minibot/docker/docker-compose.yml ps
# Or use the alias:
mb-status
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

## Shell Aliases

The following aliases are available after sourcing `~/.zshrc`:

- `mb-start` - Start services
- `mb-stop` - Stop services
- `mb-logs` - View logs
- `mb-status` - Check container status

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

# Verify password in .env matches docker-compose.yml
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

## Additional Resources

- Comprehensive setup guide: `minibot-macos-setup.md`
- Example configurations in `docker/` and `config/` directories

---

**Created:** February 2025  
**For:** Minibot macOS Experimentation Environment
