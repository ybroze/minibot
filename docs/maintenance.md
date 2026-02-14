# Maintenance Guide

## Regular Tasks

### Weekly: Security Audit

```bash
~/minibot/scripts/security-audit.sh
```

Review the output. Fix any failures before they become habits.

### Weekly: Health Check

```bash
~/minibot/scripts/health-check.sh
```

Verify all services are running and responsive.

### Monthly: Review Disk Usage

```bash
du -sh ~/minibot/data/*
```

If PostgreSQL, Redis, or OpenClaw data is growing unexpectedly, investigate.
Consider running `docker system prune` to clean up unused images and build
cache.

### Quarterly: Rotate Credentials

Rotate secrets every 3 months (or immediately if you suspect compromise):

1. Generate a new password/key.
2. Store it in the keychain:
   ```bash
   mb-secrets set POSTGRES_PASSWORD
   mb-secrets set REDIS_PASSWORD
   mb-secrets set ANTHROPIC_API_KEY
   mb-secrets set TELEGRAM_BOT_TOKEN
   mb-secrets set OPENCLAW_GATEWAY_TOKEN
   ```
3. Recreate containers so they use the new values:
   ```bash
   mb-stop
   docker compose -f ~/minibot/docker/docker-compose.yml down -v
   # WARNING: -v removes volumes. Back up first if you have data to keep.
   mb-start
   ```
   **Note:** `-v` removes Docker volumes. Back up first if you have data.
4. Revoke the old keys/tokens on the provider side too (Anthropic console,
   Telegram @BotFather `/revoke`, etc.).

When rotating an API key for an external provider, it's also a good time to
review spending limits on that provider's dashboard.

### As Needed: Update Docker Images

Check for security updates to the base images:

```bash
docker pull postgres:15-alpine
docker pull redis:7-alpine
docker pull openclaw/openclaw:latest
mb-stop && mb-start
```

### As Needed: Update macOS

```bash
# System Settings > General > Software Update
```

Reboot after updates. 

---

## Backups

### Creating a Backup

```bash
~/minibot/scripts/backup.sh
```

This stops services, copies `data/` and `docker/` to a timestamped directory
under `~/minibot-backups/`, then restarts services.

### Restoring from Backup

```bash
~/minibot/scripts/restore.sh ~/minibot-backups/20250212-143022
```

**Important:** Backups do not include keychain secrets. After restoring on a
new machine, run:

```bash
mb-secrets init
```

### Backup Retention

Keep the last 5–10 backups. Delete older ones to save space:

```bash
ls -1d ~/minibot-backups/*/ | head -n -5 | xargs rm -rf
```

---

## Log Rotation

Container logs are managed by Docker's logging driver. To check their size
and prune if needed:

```bash
# Check Docker log sizes
docker system df -v

# Truncate a specific container's log
sudo truncate -s 0 $(docker inspect --format='{{.LogPath}}' minibot-openclaw)
```

LaunchAgent logs in `~/minibot/data/logs/system/` and OpenClaw session data
in `~/minibot/data/openclaw/` may also grow over time. Periodically archive
and clear old data as needed.
