# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Minibot is a macOS-focused infrastructure project that provides a secure, isolated environment for running AI agents. It uses Docker Compose to orchestrate PostgreSQL 15, Redis 7, and OpenClaw (agent gateway/orchestrator) as services, with secrets managed via the macOS Keychain (not `.env` files). The entire codebase is shell scripts (~750 lines of bash) plus configuration and documentation.

Target platform: macOS (Sequoia / recent versions), intended to run under a dedicated `minibot` standard user account.

## Architecture

**Secrets flow:** `macOS Keychain → minibot-start.sh (exports env vars) → docker compose up → containers`

**Services:** PostgreSQL (`127.0.0.1:5432`), Redis (`127.0.0.1:6379`), and OpenClaw (`127.0.0.1:18789` gateway) on a Docker bridge network (`minibot-net`). All are localhost-only.

**Security model:** Defense-in-depth with `umask 077`, directory permissions `700`, Keychain-based secrets, Docker resource limits, and a deny-by-default agent tool policy.

**Operational lifecycle:**
- `bin/minibot-start.sh` — loads secrets from Keychain, exports as env vars, runs `docker compose up -d`
- `bin/minibot-stop.sh` — `docker compose down`
- `bin/minibot-secrets.sh` — Keychain CRUD (init, set, get, list, delete)
- `scripts/` — backup, restore, health-check, security-audit, reset, LaunchAgent management

## Key Directories

- `bin/` — User-facing operational scripts (start, stop, logs, secrets)
- `scripts/` — Maintenance scripts (backup, restore, health-check, security-audit, reset, LaunchAgent)
- `docker/` — `docker-compose.yml` and `.env.example`
- `docs/` — Threat model, emergency procedures, maintenance guide, OpenClaw setup guide

## Common Commands

```bash
# Shell aliases (defined in zshrc-additions.sh)
mb-start          # Start services
mb-stop           # Stop services
mb-logs           # View Docker logs
mb-status         # docker compose ps
mb-secrets        # Manage keychain secrets

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
- Required secrets: `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `ANTHROPIC_API_KEY`, `TELEGRAM_BOT_TOKEN`, `OPENCLAW_GATEWAY_TOKEN`
