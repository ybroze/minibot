# Secrets Management

## Overview

Minibot stores all secrets in the macOS Keychain under the service name
`minibot` — never in plaintext `.env` files. Secrets are loaded into the
shell environment on every login via `zshrc-additions.sh`, which calls
`minibot-secrets.sh export`. This means all shell commands — including
`docker compose`, `mb-stop`, `mb-logs`, and `mb-status` — have access to
the secrets without each script loading them individually.

**Flow:** `macOS Keychain → zshrc-additions.sh (exports env vars on login) → shell environment → docker compose → containers`

## Required Secrets

| Secret                     | Used by    | Description                                       |
|----------------------------|------------|---------------------------------------------------|
| `POSTGRES_PASSWORD`        | PostgreSQL | Database password for the `minibot` user          |
| `REDIS_PASSWORD`           | Redis      | Authentication password (`--requirepass`)         |
| `MONGO_PASSWORD`           | MongoDB    | Root authentication password (`minibot` user)    |
| `OPENCLAW_GATEWAY_PASSWORD`| OpenClaw   | Gateway authentication password                  |
| `RUSTDESK_PASSWORD`        | RustDesk   | Permanent password for remote desktop access      |

OpenClaw manages its own internal secrets (API keys, bot tokens) separately — they are not stored in the macOS Keychain. The gateway password, however, is Keychain-managed like the other infrastructure secrets.

**Note:** Unlike Docker service passwords, `RUSTDESK_PASSWORD` is consumed by a
native macOS application. After setting or updating it in the Keychain, run
`~/minibot/scripts/setup-rustdesk.sh` to apply it to RustDesk's configuration.

## Managing Secrets

```bash
# First-time setup (prompts for each required secret)
mb-secrets init

# Set or update a single secret
mb-secrets set POSTGRES_PASSWORD

# Retrieve a secret value
mb-secrets get POSTGRES_PASSWORD

# List all stored secret keys
mb-secrets list
```

## How It Works

Secrets are stored using the macOS `security` command:

- **Store:** `security add-generic-password -s minibot -a <KEY> -w <VALUE>`
- **Retrieve:** `security find-generic-password -s minibot -a <KEY> -w`
- **Delete:** `security delete-generic-password -s minibot -a <KEY>`

The keychain is encrypted at rest (backed by FileVault) and requires user
authentication to unlock.

## Security Considerations

- **Environment variable exposure:** Secrets are present as shell environment
  variables for the duration of every `minibot` login session (loaded by
  `zshrc-additions.sh`). On macOS, SIP and per-user process isolation prevent
  other users' processes from reading them. On a single-user dedicated machine
  the risk is low, but the secrets are not transient — they persist in the
  shell environment until the session ends.

- **Docker inspect:** Anyone with access to the Docker socket on the host can
  run `docker inspect` and see container environment variables (including
  interpolated secrets). Docker socket access is effectively root-equivalent.
  On a single-user dedicated machine this is low risk.

- **Rotation:** Rotate secrets quarterly or immediately if you suspect
  compromise. See `docs/maintenance.md` for the rotation procedure and
  `docs/emergency.md` for the emergency response process.
