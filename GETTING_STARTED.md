# Getting Started with Minibot

You've finished the installation in `README.md`. You have four services
running. This guide explains what you're looking at and how to interact
with it.

---

## What is Docker?

Docker runs applications in **containers** — lightweight, isolated
environments that share the Mac's operating system kernel but have their
own filesystem, network, and process space. Think of each container as a
sealed box: the application inside can't see the rest of your Mac, and your
Mac can't see the application's files directly.

On macOS, Docker Desktop runs a single hidden Linux virtual machine. All
your containers live inside that VM. You interact with them through the
`docker` command-line tool from your Mac's terminal.

Key concepts:

- **Image** — a read-only template for creating containers. Like a snapshot
  of an application and everything it needs to run. Example: `postgres:15-alpine`
  is the official PostgreSQL 15 image based on Alpine Linux.
- **Container** — a running instance of an image. You can start, stop, and
  restart containers without losing their data (because data is stored in
  volumes).
- **Volume** — a folder on your Mac that is mounted into a container, so
  data persists even when the container is stopped or recreated. Minibot
  stores all database data in `~/minibot/data/`.
- **Port binding** — a mapping from a port on your Mac to a port inside a
  container. Minibot binds all ports to `127.0.0.1` (localhost only), so
  they're accessible from the Mac but not from the network.
- **Docker Compose** — a tool that reads a YAML file
  (`docker/docker-compose.yml`) and starts multiple containers together as
  a group. One command brings everything up or tears everything down.

---

## What You Have Running

After `mb-start`, four containers are running inside Docker:

```
Your Mac (macOS)
│
├── Docker Desktop (hidden Linux VM)
│   │
│   ├── minibot-postgres   PostgreSQL 15 database
│   ├── minibot-redis      Redis 7 cache / message broker
│   ├── minibot-mongo      MongoDB 7 document database
│   └── minibot-openclaw   OpenClaw agent gateway
│
├── ~/minibot/data/        Persistent data (mounted into containers)
│   ├── postgres/
│   ├── redis/
│   ├── mongo/
│   └── openclaw/
│
└── macOS Keychain          Stores all passwords (not on disk)
```

The containers talk to each other over an internal Docker network called
`minibot-net`. Each container also exposes a port on `127.0.0.1` so you can
reach it from the Mac:

| Container | What it is | Port on your Mac |
|-----------|------------|------------------|
| minibot-postgres | Relational database (SQL) | `127.0.0.1:5432` |
| minibot-redis | In-memory key-value store | `127.0.0.1:6379` |
| minibot-mongo | Document database (JSON-like) | `127.0.0.1:27017` |
| minibot-openclaw | Agent gateway (HTTP/WebSocket) | `127.0.0.1:18789` |

**Why three databases?** Each is good at different things:

- **PostgreSQL** is a traditional relational database — structured tables
  with rows and columns, queried with SQL. OpenClaw uses it as its primary
  data store for users, sessions, configuration, and anything that benefits
  from strong consistency and relationships between records.
- **Redis** is an in-memory store — extremely fast, but not meant for large
  or permanent data. It's used for caching, real-time message brokering
  between components, and short-lived state like session tokens and rate
  limiters. Data lives in RAM and is periodically flushed to disk.
- **MongoDB** is a document database — it stores flexible JSON-like records
  instead of rigid table rows. It's available for agents and plugins that
  need to store unstructured or evolving data (logs, conversation history,
  scraped content) where the schema may change over time. OpenClaw itself
  doesn't use it directly, but it's on the network and ready for anything
  that needs it.

`127.0.0.1` means "this machine only." Nobody on your network can reach
these ports — they're only accessible from the Mac itself (or through an SSH
tunnel or Tailscale).

---

## How to Reach the Mac

### Sitting at the Mac

Just open Terminal. You're already logged in as the `minibot` user, your
shell aliases are loaded, and secrets are in the environment. Skip to the
next section.

### From another computer (SSH)

If you set up Tailscale during installation, you can SSH in from any device
on your tailnet:

```bash
# Find the Mac Mini's Tailscale IP (run this ON the Mac)
tailscale ip -4     # prints something like 100.64.1.23

# From your laptop or other device
ssh minibot@100.64.1.23
```

Once connected via SSH, you're in a terminal on the Mac — everything works
the same as sitting in front of it.

### Port forwarding (accessing services from your laptop)

The database ports and OpenClaw's web interface are bound to `127.0.0.1` on
the Mac, so your laptop can't reach them directly. SSH tunneling solves this
— it forwards a port on your laptop to a port on the Mac:

```bash
# Forward OpenClaw's port to your laptop
ssh -L 18789:127.0.0.1:18789 minibot@100.64.1.23

# Now open http://localhost:18789 in your laptop's browser
```

You can forward multiple ports at once:

```bash
ssh -L 5432:127.0.0.1:5432 \
    -L 18789:127.0.0.1:18789 \
    minibot@100.64.1.23
```

While that SSH session is open, `localhost:5432` on your laptop reaches
PostgreSQL on the Mac, and `localhost:18789` reaches OpenClaw.

---

## The OpenClaw Web Interface

OpenClaw is the only service with a web UI. Once services are running:

- **From the Mac:** open `http://127.0.0.1:18789` in a browser.
- **From another device:** set up an SSH tunnel (see above) or use the
  Mac's Tailscale IP if OpenClaw is configured to listen beyond localhost.

The gateway password is `OPENCLAW_GATEWAY_PASSWORD` from the Keychain. To
retrieve it:

```bash
mb-secrets get OPENCLAW_GATEWAY_PASSWORD
```

The other three services (PostgreSQL, Redis, MongoDB) are databases — they
don't have web interfaces. You interact with them through command-line
clients or through OpenClaw, which connects to them internally.

---

## Talking to Containers

### Checking what's running

```bash
mb-status
```

Healthy output:

```
NAME               STATUS
minibot-postgres   Up (healthy)
minibot-redis      Up (healthy)
minibot-mongo      Up (healthy)
minibot-openclaw   Up (healthy)
```

If a container shows `starting`, wait 30 seconds — OpenClaw takes the
longest to initialize.

### Getting a shell inside a container

This is the Docker equivalent of "SSH into a server." It drops you into a
terminal running *inside* the container:

```bash
docker exec -it minibot-postgres bash
```

- `docker exec` = "run a command in a running container"
- `-it` = "give me an interactive terminal"
- `minibot-postgres` = the container name
- `bash` = the command to run (a shell)

You're now inside the container's filesystem. Type `exit` to leave. Nothing
you do here affects your Mac directly — you're inside the container's
isolated environment.

Some containers use Alpine Linux, which has `sh` instead of `bash`:

```bash
docker exec -it minibot-redis sh
docker exec -it minibot-openclaw sh
```

You can also run a single command without entering a shell:

```bash
# Check if PostgreSQL is accepting connections
docker exec minibot-postgres pg_isready -U minibot

# Check Redis
docker exec minibot-redis redis-cli -a "$REDIS_PASSWORD" PING
```

### Reading logs

Every container writes logs. Docker captures them:

```bash
# Follow all container logs in real time (Ctrl-C to stop)
mb-logs

# Follow logs for just one service
mb-logs postgres
mb-logs openclaw

# Show the last 50 lines without following
docker compose -f ~/minibot/docker/docker-compose.yml logs --tail 50 openclaw
```

### Starting and stopping

```bash
mb-start          # Start everything (loads secrets, runs docker compose up)
mb-stop           # Stop everything (docker compose down)

# Restart a single container without touching the others
docker compose -f ~/minibot/docker/docker-compose.yml restart postgres
```

---

## Connecting to Databases

Each database has a command-line client. You can either run the client on
your Mac (if installed via Homebrew) or run it inside the container.

### PostgreSQL

```bash
# Option A: from your Mac (requires: brew install libpq)
psql -h 127.0.0.1 -U minibot -d minibot

# Option B: from inside the container (no password needed)
docker exec -it minibot-postgres psql -U minibot -d minibot
```

Once connected, try:

```sql
\l                  -- list databases
\dt                 -- list tables
\q                  -- quit
```

### Redis

```bash
# Option A: from your Mac (requires: brew install redis)
redis-cli -h 127.0.0.1 -a "$(mb-secrets get REDIS_PASSWORD)"

# Option B: from inside the container
docker exec -it minibot-redis redis-cli -a "$REDIS_PASSWORD"
```

Once connected, try:

```
PING                -- should return PONG
INFO memory         -- memory usage
DBSIZE              -- number of keys
```

### MongoDB

```bash
# Option A: from your Mac (requires: brew install mongosh)
mongosh "mongodb://minibot:$(mb-secrets get MONGO_PASSWORD)@127.0.0.1:27017/admin"

# Option B: from inside the container
docker exec -it minibot-mongo mongosh -u minibot -p "$MONGO_PASSWORD" \
    --authenticationDatabase admin
```

Once connected, try:

```javascript
show dbs            // list databases
show collections    // list collections in current db
db.serverStatus()   // server health
```

---

## Managing Secrets

Passwords are stored in the macOS Keychain — not in files. They're loaded
into your shell environment automatically when you log in.

```bash
mb-secrets list                     # which secrets are stored?
mb-secrets get POSTGRES_PASSWORD    # print a specific secret
mb-secrets set REDIS_PASSWORD       # change a secret (prompts for value)
```

After changing a secret, reload and restart:

```bash
source ~/.zshrc
mb-stop && mb-start
```

**Caveat:** PostgreSQL and MongoDB store their passwords internally on first
startup. Updating the Keychain alone won't change them. See
`docs/maintenance.md` for the full rotation procedure.

---

## Health Checks

```bash
mb-health
```

This tests everything: Keychain secrets, Docker, database connectivity,
OpenClaw, and the LaunchAgent. It prints `✓` for passing checks, `✗` for
failures, and `⚠` for warnings. It exits non-zero if anything critical
fails:

```bash
mb-health && echo "All good" || echo "Something is wrong"
```

For a security-focused check:

```bash
mb-audit
```

This verifies port bindings, authentication, file permissions, firewall, and
FileVault.

---

## Backups

```bash
# Create a backup (stops services, copies data, restarts)
~/minibot/scripts/backup.sh

# List backups
ls ~/minibot-backups/

# Restore a backup
~/minibot/scripts/restore.sh ~/minibot-backups/20260221-143022
```

Backups do **not** include Keychain secrets. To back them up separately:

```bash
mb-secrets export > ~/minibot-backups/secrets-backup.sh
chmod 600 ~/minibot-backups/secrets-backup.sh
```

---

## Updating

### OpenClaw (built from source)

```bash
mb-build                  # pulls latest source, rebuilds image
mb-stop && mb-start       # restart with new image
```

### Database images (pulled from Docker Hub)

```bash
docker pull postgres:15-alpine
docker pull redis:7-alpine
docker pull mongo:7
mb-stop && mb-start
```

---

## Troubleshooting

**Docker not found / not running** — Open Docker Desktop (`open -a Docker`),
wait for the whale icon in the menu bar to stop animating (~30-60 seconds).

**A container keeps restarting** — Check its logs (`mb-logs openclaw`) and
exit code (`docker inspect minibot-openclaw --format='{{.State.ExitCode}}'`).
Common causes: missing secrets, database not ready, image not built.

**Secrets missing after reboot** — They load from Keychain on login. Run
`mb-secrets list` to check they exist, then `source ~/.zshrc` to reload them.

**Can't connect to a database** — Check that the container is running
(`mb-status`), check its logs (`docker logs minibot-postgres --tail 50`),
and try connecting from inside the container to rule out network issues.

**Disk space running low** — Check data usage (`du -sh ~/minibot/data/*`)
and Docker overhead (`docker system df`). Clean up with
`docker system prune`.

---

## Quick Reference

| Command | What it does |
|---------|--------------|
| `mb-start` | Load secrets, start all containers |
| `mb-stop` | Stop all containers |
| `mb-status` | Show container status |
| `mb-logs [service]` | Follow logs (all or one service) |
| `mb-health` | Full health check |
| `mb-audit` | Security posture audit |
| `mb-secrets list` | Show stored secrets |
| `mb-secrets get KEY` | Print a secret value |
| `mb-build` | Rebuild OpenClaw from source |
| `docker exec -it CONTAINER sh` | Open a shell inside a container |
| `docker logs CONTAINER` | View a container's logs |

All `bin/` scripts accept `--help`.

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

See `docs/README.md` for a recommended reading order.
