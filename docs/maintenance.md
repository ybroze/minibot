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

If PostgreSQL or Redis data is growing unexpectedly, investigate. Consider
running `docker system prune` to clean up unused images and build cache.

### Quarterly: Rotate Credentials

Rotate all secrets every 3 months. The process:

1. Generate a new password/key.
2. Store it in the keychain:
   ```bash
   mb-secrets set POSTGRES_PASSWORD
   mb-secrets set REDIS_PASSWORD
   ```
3. Recreate containers so they use the new values:
   ```bash
   mb-stop
   docker compose -f ~/minibot/docker/docker-compose.yml down -v
   mb-start
   ```
   **Note:** `-v` removes Docker volumes. Back up first if you have data.
4. If you have API keys or bot tokens, rotate them on the provider side too.

### As Needed: Update Docker Images

Check for security updates to the base images:

```bash
docker pull postgres:15-alpine
docker pull redis:7-alpine
mb-stop && mb-start
```

### As Needed: Update macOS

```bash
# System Settings > General > Software Update
```

Reboot after updates. If you have the LaunchAgent installed, services will
restart automatically on login.

---

## Backups

### Creating a Backup

```bash
~/minibot/scripts/backup.sh
```

This stops services, copies `data/`, `config/`, and `docker/` to a timestamped
directory under `~/minibot-backups/`, then restarts services.

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

Minibot does not currently rotate logs automatically. If logs in
`~/minibot/data/logs/` grow large, either:

1. Set up `newsyslog` or `logrotate` (via Homebrew):
   ```bash
   brew install logrotate
   ```

2. Or periodically archive and clear old logs:
   ```bash
   tar czf ~/minibot-backups/logs-$(date +%Y%m%d).tar.gz ~/minibot/data/logs/
   rm -rf ~/minibot/data/logs/**/*.log
   ```
