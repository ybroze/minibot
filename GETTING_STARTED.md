# Minibot User Guide

This guide is for after you've completed installation (`README.md`). You have
four containers running, your shell aliases loaded, and secrets in the Keychain.
Now what?

## System Overview

```
                        macOS Keychain
                             |
    mb-start loads secrets   |   docker compose up -d
    ─────────────────────────┤────────────────────────
                             |
    ┌────────────────────────┴────────────────────────┐
    │                  minibot-net                     │
    │                                                  │
    │   minibot-postgres ─── 127.0.0.1:5432           │
    │   minibot-redis    ─── 127.0.0.1:6379           │
    │   minibot-mongo    ─── 127.0.0.1:27017          │
    │   minibot-openclaw ─── 127.0.0.1:18789          │
    │                                                  │
    └──────────────────────────────────────────────────┘
```

All ports bind to localhost only. Containers talk to each other over an
internal Docker bridge network by service name (`postgres`, `redis`, `mongo`).
OpenClaw is the agent gateway that connects to the databases internally and to
external APIs (LLM providers, Telegram) over the internet.

## Quick Reference

| Command | What it does |
|---------|--------------|
| `mb-start` | Load secrets from Keychain, start all containers |
| `mb-stop` | Stop all containers |
| `mb-status` | Show container status (`docker compose ps`) |
| `mb-logs` | Follow logs for all services |
| `mb-logs openclaw` | Follow logs for one service |
| `mb-health` | Full health check (exits non-zero on failure) |
| `mb-audit` | Security posture audit |
| `mb-secrets list` | Show which secrets are stored |
| `mb-build` | Rebuild OpenClaw image from latest source |

All `mb-*` commands are shell aliases defined in `~/minibot/zshrc-additions.sh`.
All `bin/` scripts accept `--help`.

---

## Working with Containers

### Checking status

```bash
mb-status
```

Healthy output looks like:

```
NAME               STATUS
minibot-postgres   Up (healthy)
minibot-redis      Up (healthy)
minibot-mongo      Up (healthy)
minibot-openclaw   Up (healthy)
```

If a container shows `starting`, give it 30 seconds — OpenClaw has a
`start_period` of 30 seconds in its healthcheck.

### Running commands inside containers

Use `docker exec` to run commands inside a running container:

```bash
# Open an interactive shell in any container
docker exec -it minibot-postgres bash
docker exec -it minibot-redis sh       # Alpine images use sh, not bash
docker exec -it minibot-mongo bash
docker exec -it minibot-openclaw sh

# Run a single command without an interactive session
docker exec minibot-postgres pg_isready -U minibot
```

The `-it` flags give you an interactive terminal. Omit them for
non-interactive (scripted) commands.

### Viewing logs

```bash
# Follow all logs (Ctrl-C to stop)
mb-logs

# Follow logs for a single service
mb-logs postgres
mb-logs redis
mb-logs mongo
mb-logs openclaw

# View last 50 lines without following
docker compose -f ~/minibot/docker/docker-compose.yml logs --tail 50 openclaw
```

### Restarting a single service

```bash
docker compose -f ~/minibot/docker/docker-compose.yml restart postgres
```

To restart everything: `mb-stop && mb-start`.

### Inspecting a container

```bash
# Full container details (image, env vars, mounts, network)
docker inspect minibot-openclaw

# Just the image name
docker inspect minibot-openclaw --format='{{.Config.Image}}'

# Environment variables (will include interpolated secrets)
docker inspect minibot-openclaw --format='{{json .Config.Env}}' | python3 -m json.tool
```

---

## Connecting to Databases

### PostgreSQL

```bash
# From the host (requires psql — install with: brew install libpq)
psql -h 127.0.0.1 -U minibot -d minibot

# From inside the container (no password needed — peer auth)
docker exec -it minibot-postgres psql -U minibot -d minibot
```

Useful queries:

```sql
-- List databases
\l

-- List tables in current database
\dt

-- Check database size
SELECT pg_size_pretty(pg_database_size('minibot'));

-- Show active connections
SELECT pid, usename, state, query FROM pg_stat_activity;
```

### Redis

```bash
# From the host (requires redis-cli — install with: brew install redis)
redis-cli -h 127.0.0.1 -a "$(mb-secrets get REDIS_PASSWORD)"

# From inside the container
docker exec -it minibot-redis redis-cli -a "$REDIS_PASSWORD"
```

Useful commands:

```
PING                    # Should return PONG
INFO memory             # Memory usage
INFO keyspace           # Number of keys per database
DBSIZE                  # Number of keys in current database
KEYS *                  # List all keys (use cautiously in production)
```

### MongoDB

```bash
# From the host (requires mongosh — install with: brew install mongosh)
mongosh "mongodb://minibot:$(mb-secrets get MONGO_PASSWORD)@127.0.0.1:27017/admin"

# From inside the container
docker exec -it minibot-mongo mongosh -u minibot -p "$MONGO_PASSWORD" --authenticationDatabase admin
```

Useful commands:

```javascript
// List databases
show dbs

// Switch database
use minibot

// List collections
show collections

// Check server status
db.serverStatus()
```

---

## Managing Secrets

Secrets live in the macOS Keychain — never on disk.

```bash
# See which secrets are stored
mb-secrets list

# Retrieve a specific secret (prints to stdout)
mb-secrets get POSTGRES_PASSWORD

# Update a secret (prompts interactively)
mb-secrets set REDIS_PASSWORD

# Generate a new random password and store it
mb-secrets generate REDIS_PASSWORD

# Print all required key names
mb-secrets keys

# Export as shell variables (this is what zshrc-additions.sh calls on login)
mb-secrets export
```

After changing a secret, reload your shell and restart services:

```bash
source ~/.zshrc
mb-stop && mb-start
```

**Important:** PostgreSQL and MongoDB only read password env vars on first
initialization. Changing the Keychain value alone won't update the database's
internal password. See `docs/maintenance.md` for the full rotation procedure.

---

## Backups and Restore

### Creating a backup

```bash
~/minibot/scripts/backup.sh
```

This stops services, copies `data/` and `docker/` to
`~/minibot-backups/<timestamp>/`, then restarts services. Takes a few minutes
depending on data size.

Keychain secrets are **not** included in backups. To export them separately:

```bash
mb-secrets export > ~/minibot-backups/secrets-backup.sh
chmod 600 ~/minibot-backups/secrets-backup.sh
```

### Restoring from a backup

```bash
# List available backups
ls ~/minibot-backups/

# Restore a specific backup
~/minibot/scripts/restore.sh ~/minibot-backups/20260221-143022
```

The restore script stops services, swaps the data directories (with rollback
on failure), and restarts services.

### Backup retention

Keep the last 5-10 backups:

```bash
ls -1d ~/minibot-backups/*/ | head -n -5 | xargs rm -rf
```

---

## Health Checks and Auditing

### Health check

```bash
mb-health
```

Tests Keychain secrets, Docker, each database, OpenClaw, and the LaunchAgent.
Exits non-zero if any critical check fails, so you can script it:

```bash
mb-health && echo "All services healthy" || echo "Something is down"
```

### Security audit

```bash
mb-audit
```

Checks port bindings, authentication, file permissions, umask, firewall, and
FileVault. Run weekly. Exits non-zero if any check fails outright.

---

## Remote Access

### Via Tailscale

If Tailscale is set up, services are reachable from any device on your tailnet
using the Mac Mini's Tailscale IP:

```bash
# Find the Mac Mini's Tailscale IP
tailscale ip -4

# From another device, SSH in
ssh minibot@100.x.x.x
```

### Via SSH tunnel

Forward specific ports to your local machine:

```bash
ssh -L 5432:127.0.0.1:5432 \
    -L 6379:127.0.0.1:6379 \
    -L 27017:127.0.0.1:27017 \
    -L 18789:127.0.0.1:18789 \
    minibot@<machine-ip>
```

Then connect to `localhost:5432`, `localhost:18789`, etc. from your local tools.

---

## Updating OpenClaw

```bash
# Pull latest source and rebuild the Docker image
mb-build

# Restart to pick up the new image
mb-stop && mb-start
```

The build uses `--progress=plain` so you see real-time output.

## Updating Base Images

```bash
docker pull postgres:15-alpine
docker pull redis:7-alpine
docker pull mongo:7
mb-stop && mb-start
```

---

## Troubleshooting

### Docker not found / not running

```bash
open -a Docker
```

Wait for the whale icon to settle (~30-60 seconds), then retry.

### A container keeps restarting

```bash
# Check its logs
mb-logs openclaw

# Check the exit code
docker inspect minibot-openclaw --format='{{.State.ExitCode}}'
```

Common causes: missing secrets, database not ready yet, image not built.

### Secrets missing after reboot

Secrets load from Keychain on shell login via `zshrc-additions.sh`. If they're
missing:

```bash
mb-secrets list          # Are they in the Keychain?
source ~/.zshrc          # Reload them into the environment
echo "$POSTGRES_PASSWORD" # Verify they're set (should print a value)
```

### Database won't accept connections

```bash
# Check if the container is running
docker ps | grep minibot-postgres

# Check the container's internal logs
docker logs minibot-postgres --tail 50

# Test from inside the container (bypasses network)
docker exec minibot-postgres pg_isready -U minibot
```

### Disk space running low

```bash
# Check Minibot data usage
du -sh ~/minibot/data/*

# Check Docker disk usage
docker system df

# Clean up unused images and build cache (safe)
docker system prune
```

---

## Further Reading

| Topic | File |
|-------|------|
| Threat model | `docs/threat-model.md` |
| Security posture | `docs/security.md` |
| Secrets management | `docs/secrets.md` |
| Networking | `docs/networking.md` |
| Filesystem security | `docs/filesystem.md` |
| Maintenance schedule | `docs/maintenance.md` |
| Emergency procedures | `docs/emergency.md` |
| OpenClaw configuration | `misc/openclaw-setup-guide.md` |

See `docs/README.md` for a recommended reading order.
