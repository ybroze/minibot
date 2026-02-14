# Filesystem security

Minibot uses the macOS Keychain for secrets, so there are no plaintext
passwords or API keys on disk. This is a deliberate improvement over the
common `.env` file pattern, where a single `cat` or stray backup can expose
everything.

For the files that *are* on disk, minibot takes a belt-and-suspenders approach:

- **`umask 077`** is set in the shell profile (`zshrc-additions.sh`), so every
  file the minibot user creates is owner-only (`rwx------`) by default. This
  prevents loose permissions from being created in the first place.
- **`data/`** is set to `700` during install.
- **`security-audit.sh`** checks for permission drift and an incorrect umask.

**Known limitation — log file ownership:** Files created inside Docker volumes
may be owned by root or by the container's internal user, not the minibot host
user. The `data/` directory is `700`, which prevents other host users from
reading the logs, but the files inside may have looser permissions than
expected. The `security-audit.sh` script checks for this.
