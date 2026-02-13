# Minibot Repository — Code Review

**Reviewed:** February 12, 2026
**Target platform:** macOS Sequoia / very recent macOS

---

## Critical Bugs

### 1. `docker-compose` (v1) is deprecated and likely absent

Every script and alias in the repo uses the standalone `docker-compose` binary (Compose V1). Docker officially removed Compose V1 in July 2023, and Docker Desktop on macOS now ships only the `docker compose` plugin (V2). On a fresh macOS setup, none of these scripts will work.

**Affected files:** `bin/minibot-start.sh`, `bin/minibot-stop.sh`, `bin/minibot-logs.sh`, `scripts/health-check.sh`, `scripts/reset.sh`, `zshrc-additions.sh` (`mb-status` alias), `README.md`, `minibot-macos-setup.md`

**Fix:** Replace all instances of `docker-compose` with `docker compose` (space, not hyphen). Or add a shim at the top of each script:

```bash
compose_cmd() { docker compose "$@"; }
```

### 2. `brew install docker` won't give you a working Docker daemon

The README instructs:

```bash
brew install git docker docker-compose python@3.11 node@20
```

On macOS, the `docker` Homebrew formula installs only the CLI client — not the Docker Engine (daemon). macOS requires Docker Desktop to run containers. Similarly, the `docker-compose` formula installs the deprecated V1 binary.

**Fix:** Replace with:

```bash
brew install --cask docker   # Docker Desktop (includes CLI + daemon + compose plugin)
```

And remove `docker-compose` from the install list entirely.

### 3. Missing `.env.example` file

The README (step 6) and `install.sh` output both tell the user to run:

```bash
cp .env.example .env
```

But no `.env.example` file exists anywhere in the repository. This step will fail.

**Fix:** Create `docker/.env.example` with at minimum:

```
POSTGRES_PASSWORD=changeme
```

### 4. `health-check.sh` recursive glob fails silently in bash

Line in `health-check.sh`:

```bash
grep -i "error" ~/minibot/data/logs/**/*.log
```

The `**` recursive glob requires `shopt -s globstar` in bash. The script uses `#!/bin/bash`, and macOS bash (3.2) doesn't even support `globstar` at all. This line will only match files directly in `logs/`, not in subdirectories like `logs/agents/` or `logs/system/`.

**Fix:** Either change the shebang to `#!/bin/zsh` (which supports `**` natively), or replace with:

```bash
find ~/minibot/data/logs -name "*.log" -exec grep -li "error" {} \;
```

---

## Medium Issues

### 5. README references obsolete macOS UI element

Step 1 says:

> Click the lock icon to make changes

The lock icon in System Settings was removed in macOS Ventura (13.0). On Sonoma and Sequoia, authentication happens inline via Touch ID or password prompt when you attempt a change. This instruction will confuse users on any recent macOS.

**Fix:** Remove the "click the lock icon" line. Just say "Click Add Account."

### 6. `sysadminctl -password` flag ambiguity

In `minibot-macos-setup.md`:

```bash
sudo sysadminctl -addUser minibot -fullName "Minibot Experiments" -password -admin
```

The `-password` flag without a value is ambiguous. Depending on macOS version, the parser may interpret `-admin` as the password string, or it may fail. Modern `sysadminctl` expects `-password <value>` or the use of `-` for interactive prompt.

**Fix:** Either provide an explicit password or use the interactive prompt form clearly:

```bash
sudo sysadminctl -addUser minibot -fullName "Minibot Experiments" -password - -admin
```

### 7. Redundant `postgresql@15` Homebrew install

The README installs `postgresql@15` via Homebrew, but PostgreSQL is already running in Docker on port 5432. This creates a potential port conflict if the Homebrew-installed PostgreSQL service starts, and is confusing for users.

**Fix:** Remove `postgresql@15` from the `brew install` line. If you need the `psql` CLI client for debugging, install `libpq` instead:

```bash
brew install libpq
```

### 8. `version: '3.8'` in docker-compose.yml is deprecated

Docker Compose V2 ignores the `version` key and emits a deprecation warning. While not a functional bug, it produces noisy output.

**Fix:** Remove the `version: '3.8'` line entirely from `docker/docker-compose.yml`.

### 9. `minibot-macos-setup.md` has orchestrator uncommented

The actual `docker/docker-compose.yml` correctly comments out the orchestrator service (since there's no Dockerfile). But the docker-compose example embedded in `minibot-macos-setup.md` has the orchestrator **uncommented**, which would cause `docker compose up` to fail with a missing Dockerfile error if someone copies from that doc instead.

**Fix:** Comment out the orchestrator service in `minibot-macos-setup.md` to match the actual `docker-compose.yml`, or add a note that it's a placeholder.

---

## Low / Cosmetic Issues

### 10. Duplicate `.gitignore` creation

`setup-minibot-dirs.sh` creates a basic `.gitignore`, then `install.sh` overwrites it with the more comprehensive `gitignore-template`. The setup script's version is effectively dead code.

**Fix:** Remove the `.gitignore` creation from `setup-minibot-dirs.sh` and let `install.sh` handle it, or have `setup-minibot-dirs.sh` copy the template.

### 11. `minibot-logs.sh` missing `set -e`

The other two bin scripts (`minibot-start.sh`, `minibot-stop.sh`) use `set -e` for fail-fast behavior, but `minibot-logs.sh` does not. Minor inconsistency.

### 12. Backups are uncompressed

`backup.sh` uses `cp -r` which means backups of large PostgreSQL data directories will consume significant disk space quickly. Consider `tar czf` instead.

### 13. `zshrc-additions.sh` appended without newline guard

`install.sh` appends `zshrc-additions.sh` to `~/.zshrc` without ensuring a leading newline. If `~/.zshrc` doesn't end with a newline, the first line of the additions will be concatenated with the last line of the existing file.

**Fix:** Add `echo ""` before the `cat` append, or prefix the additions file with a blank line.

### 14. `Dockerfiles/` directory is empty

The directory exists but contains no files. The `docker-compose.yml` references `docker/Dockerfiles/orchestrator.Dockerfile` in the commented-out orchestrator service. If someone uncomments it, it will fail. Consider adding a placeholder `README.md` in that directory explaining that Dockerfiles should be added here.

---

## Summary

| Severity | Count | Key themes |
|----------|-------|------------|
| Critical | 4 | Docker Compose V1/V2, Docker Desktop install, missing `.env.example`, bash glob |
| Medium | 5 | Stale macOS UI references, sysadminctl syntax, port conflicts, doc/code mismatch |
| Low | 5 | Cosmetic inconsistencies, missing compression, empty placeholder dirs |

The most impactful fix is replacing `docker-compose` → `docker compose` and `brew install docker` → `brew install --cask docker` across the entire repo. Without those two changes, the project won't run on a fresh macOS setup at all.
