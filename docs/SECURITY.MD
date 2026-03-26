# Security Posture & Known Limitations

## Container Isolation

Minibot uses Docker Desktop for macOS, which runs all containers inside a
single Linux VM (backed by Apple's Virtualization.framework). This means
containers are isolated from each other via Linux namespaces and cgroups, but
they share the same kernel within the VM.

If Apple ships native macOS containerization with true per-container
isolation, that would be the natural upgrade path. Until then, Docker
Desktop's VM-based approach is the most practical option.

### Why not Podman?

Podman on macOS uses the same architecture — a Linux VM (`podman machine`)
with all containers running inside it. It does not improve the isolation
model. Podman's main advantage (rootless by default) is less relevant on
macOS where Docker Desktop already runs in a user-space VM. The migration
cost (rewriting all scripts, replacing Docker Compose, reworking the
LaunchAgent) is not justified by the marginal security difference.

## What this setup defends well against

- **Accidental execution of malicious code** as your daily user — the
  dedicated `minibot` account limits blast radius.
- **Supply-chain compromise** in your own git repos or scripts — the minibot
  user has no access to your primary account's data.
- **API key / bot token leak** via misconfiguration — secrets are in the
  macOS Keychain, not in plaintext files on disk.
- **Financial runaway from LLM agents** — Docker resource limits prevent host
  exhaustion; provider-side spending caps prevent unbounded API bills.
- **Unsolicited inbound network attacks** — the macOS firewall blocks
  inbound connections, all ports are localhost-only, and remote access is via
  Tailscale or SSH tunnel. See [networking.md](networking.md).

## What this setup is weaker against

- **Container-to-host breakout** exploiting Docker Desktop, the
  Virtualization.framework VM, or the Linux kernel inside it. This is the
  main limitation of VM-based container runtimes on macOS.
- **Physical access** — mitigated by FileVault full-disk encryption but not
  perfect (recovery key compromise, firmware exploits).
- **Malicious code running as the minibot user** — a compromised process has
  access to the network, disk, Docker socket, and Tailscale keys. The
  `umask 077` and `700` permissions limit exposure to other users but not to
  processes running as `minibot`.
- **Docker inspect exposure** — anyone who can run `docker inspect` on the
  host can read container environment variables, including interpolated
  secrets. This applies equally to Docker and Podman.

## Related documentation

- [threat-model.md](threat-model.md) — per-threat analysis with mitigations
  and residual risks
- [networking.md](networking.md) — multi-layer network security approach
- [secrets.md](secrets.md) — how credentials are stored and managed
