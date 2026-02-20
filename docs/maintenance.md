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

If PostgreSQL, Redis, MongoDB, or OpenClaw data is growing unexpectedly, investigate.
Consider running `docker system prune` to clean up unused images and build
cache.

### Quarterly: Rotate Credentials

Rotate secrets every 3 months (or immediately if you suspect compromise).
See `docs/emergency.md` for the emergency rotation process.

> **Important:** PostgreSQL and MongoDB only read their password environment
> variables on **first initialization** (when the data directory is empty).
> After that, passwords are stored inside the database itself. Simply updating
> the Keychain and restarting will **not** change the database password — the
> container will start with the old internal password while the connection
> string has the new one, causing authentication failures.

**Redis and OPENCLAW_GATEWAY_PASSWORD** are simple — they read their
passwords from environment variables on every start. Just update the Keychain
and restart.

#### Full rotation procedure

1. **Back up first:**
   ```bash
   ~/minibot/scripts/backup.sh
   ```

2. **Change passwords inside the running databases:**

   ```bash
   # PostgreSQL — change the internal password
   docker exec -it minibot-postgres psql -U minibot -c \
     "ALTER USER minibot WITH PASSWORD 'NEW_PG_PASSWORD';"

   # MongoDB — change the internal password
   docker exec -it minibot-mongo mongosh -u minibot \
     -p "$(mb-secrets get MONGO_PASSWORD)" --authenticationDatabase admin \
     --eval 'db.getSiblingDB("admin").changeUserPassword("minibot", "NEW_MONGO_PASSWORD")'
   ```

3. **Update the Keychain to match:**
   ```bash
   mb-secrets set POSTGRES_PASSWORD    # enter NEW_PG_PASSWORD
   mb-secrets set REDIS_PASSWORD       # enter new Redis password
   mb-secrets set MONGO_PASSWORD       # enter NEW_MONGO_PASSWORD
   mb-secrets set OPENCLAW_GATEWAY_PASSWORD
   ```

4. **Reload secrets and restart:**
   ```bash
   source ~/.zshrc   # picks up new Keychain values
   mb-stop && mb-start
   ```

5. **Verify connectivity:**
   ```bash
   ~/minibot/scripts/health-check.sh
   ```

6. Rotate any OpenClaw-managed secrets (API keys, bot tokens) through
   OpenClaw's own configuration.

#### Alternative: clean wipe rotation

If you don't need to preserve data (or have a backup), you can wipe the
database volumes and let the containers re-initialize with new passwords:

```bash
mb-stop
rm -rf ~/minibot/data/postgres ~/minibot/data/mongo
mb-secrets set POSTGRES_PASSWORD
mb-secrets set REDIS_PASSWORD
mb-secrets set MONGO_PASSWORD
mb-secrets set OPENCLAW_GATEWAY_PASSWORD
source ~/.zshrc
mb-start
```

When rotating an API key for an external provider, it's also a good time to
review spending limits on that provider's dashboard.

### As Needed: Update Docker Images

Check for security updates to the base images:

```bash
docker pull postgres:15-alpine
docker pull redis:7-alpine
docker pull mongo:7
~/minibot/scripts/build-openclaw.sh    # Rebuilds openclaw:local from source
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
~/minibot/scripts/restore.sh ~/minibot-backups/20260212-143022
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
