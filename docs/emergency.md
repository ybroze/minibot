# Emergency Procedures

## If You Suspect Compromise

### Step 1: Stop Everything Immediately

```bash
~/minibot/bin/minibot-stop.sh
```

If that fails or you don't trust the scripts:

```bash
docker kill minibot-postgres minibot-redis minibot-mongo minibot-openclaw 2>/dev/null
docker compose -f ~/minibot/docker/docker-compose.yml down 2>/dev/null
```

### Step 2: Rotate All Secrets

Even if you're not sure the secrets were exfiltrated, rotate them
preemptively. The cost of a false alarm is minutes; the cost of leaving
compromised credentials active can be severe.

> **Important:** PostgreSQL and MongoDB store passwords internally — updating
> the Keychain alone won't change them. See `docs/maintenance.md` for the
> full rotation procedure. In an emergency, the simplest approach is a clean
> wipe:

```bash
# Wipe database volumes so containers re-initialize with new passwords
rm -rf ~/minibot/data/postgres ~/minibot/data/mongo

# Set new values in the keychain
~/minibot/bin/minibot-secrets.sh set POSTGRES_PASSWORD
~/minibot/bin/minibot-secrets.sh set REDIS_PASSWORD
~/minibot/bin/minibot-secrets.sh set MONGO_PASSWORD
~/minibot/bin/minibot-secrets.sh set OPENCLAW_GATEWAY_PASSWORD

# Reload secrets into shell environment
source ~/.zshrc
```

If you need to preserve database data, follow the in-place rotation steps
in `docs/maintenance.md` instead.

Also rotate any OpenClaw-managed secrets (API keys, bot tokens) through
OpenClaw's own configuration.

### Step 3: Investigate

```bash
# Check for unauthorized processes
ps aux | grep -i "minibot\|node\|python\|curl\|wget"

# Check for recently modified scripts (should not change after install)
find ~/minibot/bin ~/minibot/scripts -newer ~/minibot/install.sh -type f

# Check Docker for unknown containers
docker ps -a

# Review recent OpenClaw session logs
ls -lt ~/minibot/data/openclaw/agents/*/sessions/*.jsonl 2>/dev/null | head -20

# Review LaunchAgent logs
ls -lt ~/minibot/data/logs/system/*.log 2>/dev/null | head -20
```

### Step 4: Decide on Recovery

**If the investigation is inconclusive:**
- Restart services with the new secrets: `~/minibot/bin/minibot-start.sh`
- Monitor closely for the next 24 hours.

**If compromise is confirmed:**
- Assume all data on the machine is exposed (database contents, OpenClaw state,
  any file the minibot user can read).
- Change all passwords that may have been accessible (API keys, email, etc.).
- Consider reformatting the machine and reinstalling from scratch.
- Restore from a known-good backup: `~/minibot/scripts/restore.sh <backup-dir>`
- Re-initialize secrets: `~/minibot/bin/minibot-secrets.sh init`

---

## If API Bills Are Unexpectedly High

### Step 1: Stop services

```bash
~/minibot/bin/minibot-stop.sh
```

### Step 2: Check provider dashboards

Check the usage and billing pages for each provider (Anthropic console,
Telegram, etc.) to identify which model or endpoint spiked.

### Step 3: Review logs for loops

Look for repeated tool calls or rapid-fire API requests in the OpenClaw
session logs under `~/minibot/data/openclaw/`.

### Step 4: Lower limits before restarting

Adjust spending limits on the provider dashboard before bringing services
back up.

---

## If an Agent Behaves Erratically

### Soft reset: Clear the session

If you have a messaging channel connected, send `/new` to reset the session.
Or from the CLI:

```bash
# List active sessions via Docker
docker exec minibot-openclaw ls /home/node/.openclaw/agents/ 2>/dev/null
```

### Hard reset: Wipe agent state

```bash
~/minibot/bin/minibot-stop.sh
rm -rf ~/minibot/data/openclaw/*
~/minibot/bin/minibot-start.sh
```

### Nuclear reset: Full environment reset

```bash
~/minibot/scripts/reset.sh
```

This destroys all data, containers, and volumes. The script will prompt
to rotate secrets; if you skip that step, run `minibot-secrets.sh init`
manually before restarting.
