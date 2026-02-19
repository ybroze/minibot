# Networking & Port Security

Minibot uses a multi-layer approach to network security. No service is ever
exposed to the public internet. For the full threat analysis, see
[threat-model.md](threat-model.md) (especially Threat 2: Network Exposure).

---

## Layer 1: macOS Firewall

The macOS application firewall blocks unsolicited inbound connections at the
OS level. This is the outermost defense and is enabled during initial machine
hardening (see README.md, "Initial Machine Hardening").

```bash
# Verify the firewall is enabled
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

The `security-audit.sh` script checks this automatically.

---

## Layer 2: Localhost-Only Port Binding

All Docker container ports are bound to `127.0.0.1`, making them accessible
only from the host machine — not from the local network or the internet.

| Service    | Container          | Host Binding           | Purpose                |
|------------|--------------------|------------------------|------------------------|
| PostgreSQL | minibot-postgres   | `127.0.0.1:5432`      | Database               |
| Redis      | minibot-redis      | `127.0.0.1:6379`      | Cache / message broker |
| MongoDB    | minibot-mongo      | `127.0.0.1:27017`     | Document database      |
| OpenClaw   | minibot-openclaw   | `127.0.0.1:18789`     | Gateway (WebSocket)    |

This is enforced in `docker/docker-compose.yml`. The `security-audit.sh`
script verifies that no port binding in the compose file omits the
`127.0.0.1` prefix.

**Important:** Never change a port binding to `0.0.0.0` or remove the
`127.0.0.1` prefix. Doing so would expose that service to your entire
network.

---

## Layer 3: Docker Bridge Network

All three services communicate over an internal Docker bridge network
(`minibot-net`). Within this network, containers can reach each other by
service name (e.g., `postgres`, `redis`) without any traffic leaving the
Docker host.

This means OpenClaw can connect to PostgreSQL at `postgres:5432` and Redis at
`redis:6379` internally, without those connections traversing the host
network stack.

---

## Layer 4: Service-Level Authentication

Even if a service is reachable, it requires credentials:

- **PostgreSQL** — requires `POSTGRES_PASSWORD` for the `minibot` database
  user.
- **Redis** — requires `REDIS_PASSWORD` via `--requirepass`. Unauthenticated
  `PING` commands are rejected.
- **MongoDB** — requires `MONGO_PASSWORD` for the `minibot` root user via
  `MONGO_INITDB_ROOT_PASSWORD`.
- **OpenClaw** — requires `OPENCLAW_GATEWAY_PASSWORD` for gateway access,
  managed via the macOS Keychain alongside other infrastructure secrets.

See [secrets.md](secrets.md) for how credentials are managed.

---

## Layer 5: Docker Resource Limits

Each container has CPU and memory limits to prevent a single runaway service
from exhausting the host:

| Service    | Memory Limit | CPU Limit |
|------------|-------------|-----------|
| PostgreSQL | 1 GB        | 1.0 CPU   |
| Redis      | 256 MB      | 0.5 CPU   |
| MongoDB    | 1 GB        | 1.0 CPU   |
| OpenClaw   | 4 GB        | 2.0 CPUs  |

These are set via `deploy.resources.limits` in `docker-compose.yml`.

---

## Remote Access

Remote access to the Minibot machine is handled exclusively through:

1. **Tailscale** (recommended) — creates a private mesh VPN. Services are
   reachable via the machine's Tailscale IP (`100.x.x.x`) without any port
   changes. See README.md for setup.

2. **SSH tunnel** — forward specific ports over SSH:
   ```bash
   ssh -L 5432:127.0.0.1:5432 -L 27017:127.0.0.1:27017 -L 18789:127.0.0.1:18789 minibot@<machine-ip>
   ```

Neither method requires changing any port bindings or firewall rules.

---

## Outbound Connections

OpenClaw makes outbound HTTPS connections to external APIs:

- **Anthropic API** (`api.anthropic.com`) — LLM inference
- **Telegram Bot API** (`api.telegram.org`) — messaging channel

These outbound connections are not restricted by Minibot. Rate and spend
limits should be configured on the provider side (see README.md, "Configure
API Spending Limits").

---

## Verification

Run the security audit to verify the networking posture:

```bash
~/minibot/scripts/security-audit.sh
```

This checks:
- All ports are bound to `127.0.0.1`
- Redis rejects unauthenticated connections
- MongoDB rejects unauthenticated access
- The macOS firewall is enabled
