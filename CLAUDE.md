# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Minibot is a macOS-focused infrastructure project that provides a secure, isolated environment for running AI agents. It uses Docker Compose to orchestrate PostgreSQL 15, Redis 7, MongoDB 7, and OpenClaw (agent gateway/orchestrator) as services, with secrets managed via the macOS Keychain (not `.env` files). The entire codebase is shell scripts (~1150 lines of bash) plus configuration and documentation.

Target platform: macOS (Sequoia / recent versions), intended to run under a dedicated `minibot` standard user account.

## Architecture

**Secrets flow:** `macOS Keychain → zshrc-additions.sh (exports env vars on login) → shell environment → docker compose → containers`

**Services:** PostgreSQL (`127.0.0.1:5432`), Redis (`127.0.0.1:6379`), MongoDB (`127.0.0.1:27017`), and OpenClaw (`127.0.0.1:18789` gateway) on a Docker bridge network (`minibot-net`). All are localhost-only.

**Security model:** Defense-in-depth with `umask 077`, directory permissions `700`, Keychain-based secrets, Docker resource limits, and a deny-by-default agent tool policy.

**Operational lifecycle:**
- `bin/minibot-start.sh` — loads secrets from Keychain, verifies all are present, runs `docker compose up -d`
- `bin/minibot-stop.sh` — `docker compose down`
- `bin/minibot-secrets.sh` — Keychain CRUD (init, set, get, list, delete)
- `scripts/admin-setup.sh` — one-time machine setup (run as admin before `install.sh`)
- `scripts/` — backup, restore, health-check, security-audit, reset, LaunchAgent management

## Key Directories

- `bin/` — User-facing operational scripts (start, stop, logs, secrets)
- `scripts/` — Maintenance scripts (admin-setup, backup, restore, health-check, security-audit, reset, LaunchAgent)
- `docker/` — `docker-compose.yml` and `.env.example`
- `docs/` — Threat model, emergency procedures, maintenance guide, secrets, networking, security posture, filesystem security
- `misc/` — Personal notes and reference material; not part of the polished repo. Do not reference `misc/` from other docs.

## Common Commands

```bash
# Shell aliases (defined in zshrc-additions.sh)
mb-build          # Build OpenClaw image from source
mb-start          # Start services
mb-stop           # Stop services
mb-logs           # View Docker logs
mb-status         # docker compose ps
mb-secrets        # Manage keychain secrets
mb-health         # Run health check
mb-audit          # Run security audit

# Direct script invocation
~/minibot/bin/minibot-start.sh
~/minibot/bin/minibot-secrets.sh init    # First-time keychain setup
~/minibot/scripts/health-check.sh
~/minibot/scripts/security-audit.sh
~/minibot/scripts/backup.sh
~/minibot/scripts/restore.sh <backup-dir>
~/minibot/scripts/reset.sh              # DESTRUCTIVE: deletes all data
```

## Shell Script Conventions

- All scripts use `set -euo pipefail`
- Keychain operations use `security find-generic-password` / `security add-generic-password` with service name `minibot`
- Required secrets: `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `MONGO_PASSWORD`, `OPENCLAW_GATEWAY_PASSWORD`
- OpenClaw manages its own internal secrets (API keys, bot tokens) separately
- **Credential rotation caveat:** PostgreSQL and MongoDB only read password env vars on first init — see `docs/maintenance.md` for the correct rotation procedure
