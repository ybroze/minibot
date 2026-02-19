# Secrets Management

## Overview

Minibot stores all secrets in the macOS Keychain under the service name
`minibot` — never in plaintext `.env` files. Secrets are loaded just-in-time
by `minibot-start.sh`, which exports them as environment variables before
running `docker compose up`.

**Flow:** `macOS Keychain → minibot-start.sh (exports env vars) → docker compose up → containers`

## Required Secrets

| Secret                     | Used by    | Description                                       |
|----------------------------|------------|---------------------------------------------------|
| `POSTGRES_PASSWORD`        | PostgreSQL | Database password for the `minibot` user          |
| `REDIS_PASSWORD`           | Redis      | Authentication password (`--requirepass`)         |
| `MONGO_PASSWORD`           | MongoDB    | Root authentication password (`minibot` user)    |
| `OPENCLAW_GATEWAY_PASSWORD`| OpenClaw   | Gateway authentication password                  |

OpenClaw manages its own internal secrets (API keys, bot tokens) separately — they are not stored in the macOS Keychain. The gateway password, however, is Keychain-managed like the other infrastructure secrets.

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

- **Environment variable window:** Secrets are briefly present in shell
  environment variables when `minibot-start.sh` runs. On macOS, SIP and
  per-user process isolation mitigate the risk of other processes reading them.

- **Docker inspect:** Anyone with access to the Docker socket on the host can
  run `docker inspect` and see container environment variables (including
  interpolated secrets). Docker socket access is effectively root-equivalent.
  On a single-user dedicated machine this is low risk.

- **Rotation:** Rotate secrets quarterly or immediately if you suspect
  compromise. See `docs/maintenance.md` for the rotation procedure and
  `docs/emergency.md` for the emergency response process.
