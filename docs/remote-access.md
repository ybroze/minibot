# Remote Desktop Access (RustDesk)

Minibot uses [RustDesk](https://rustdesk.com/) for remote graphical access to
the Mac Mini. RustDesk runs in **direct IP mode** over Tailscale — no relay or
rendezvous server is used.

For the threat analysis, see [threat-model.md](threat-model.md) (Threat 7:
Remote Desktop Compromise).

---

## Architecture

```
Your laptop ──[Tailscale/WireGuard]──> minibot Mac Mini (RustDesk, Tailscale IP:21118)
```

- **Transport:** Tailscale (WireGuard) handles encryption and NAT traversal.
- **Authentication:** RustDesk permanent password stored in the macOS Keychain.
- **No server components:** No hbbs/hbbr containers. The RustDesk client on the
  minibot machine accepts direct connections.
- **LAN discovery disabled:** The machine does not advertise itself on the local
  network.

---

## Prerequisites

- Tailscale installed and connected on both the minibot machine and your client
- RustDesk installed: `brew install --cask rustdesk`
- macOS permissions granted (System Settings > Privacy & Security):
  - **Accessibility** — allows RustDesk to inject keyboard/mouse input
  - **Screen Recording** — allows RustDesk to capture the screen

---

## Setup (minibot machine)

```bash
# 1. Set the permanent password in the Keychain
mb-secrets set RUSTDESK_PASSWORD

# 2. Configure RustDesk for direct IP mode
~/minibot/scripts/setup-rustdesk.sh

# 3. Install the LaunchAgent (auto-start on login, restart on crash)
~/minibot/scripts/install-launchagent-rustdesk.sh

# 4. Install the caffeinate LaunchAgent (prevent sleep)
~/minibot/scripts/install-launchagent-caffeinate.sh

# 5. Verify
~/minibot/scripts/health-check.sh
```

## Connecting from your client

1. Install RustDesk on your client machine.
2. In the RustDesk connection dialog, enter the minibot machine's **Tailscale IP**
   (e.g., `100.x.y.z`) as the remote ID.
3. Enter the permanent password when prompted.

You can find the Tailscale IP by running `tailscale ip -4` on the minibot
machine, or by checking the Tailscale admin console.

---

## Headless Operation

The minibot machine is configured for 24/7 headless operation:

| Setting | How | Purpose |
|---|---|---|
| `pmset sleep 0` | `admin-setup.sh` | Prevent system sleep |
| `pmset displaysleep 0` | `admin-setup.sh` | Prevent display sleep |
| `pmset disksleep 0` | `admin-setup.sh` | Prevent disk sleep |
| `pmset autorestart 1` | `admin-setup.sh` | Auto-restart after power failure |
| `pmset womp 1` | `admin-setup.sh` | Wake on LAN |
| `caffeinate -s` | LaunchAgent | Belt-and-suspenders sleep prevention |

The `health-check.sh` script verifies these settings are active.

---

## Password Rotation

```bash
mb-secrets set RUSTDESK_PASSWORD       # enter new password
~/minibot/scripts/setup-rustdesk.sh    # apply to RustDesk
```

Unlike database passwords, RustDesk password rotation is immediate — no
service restart or data migration required.

---

## Troubleshooting

**RustDesk is not running:**
```bash
# Check the process
pgrep -x RustDesk

# Check the LaunchAgent
launchctl list | grep minibot

# Check LaunchAgent logs
tail -20 ~/minibot/data/logs/system/rustdesk-stderr.log
```

**Cannot connect:**
- Verify Tailscale is connected on both machines: `tailscale status`
- Verify RustDesk is running on the minibot machine
- Verify you are using the Tailscale IP, not a local network IP
- Check that macOS Accessibility and Screen Recording permissions are granted

**Black screen after connecting:**
- macOS Screen Recording permission may not be granted to RustDesk
- System Settings > Privacy & Security > Screen Recording > enable RustDesk
- You may need to quit and relaunch RustDesk after granting the permission

**Machine is unreachable:**
- Check Tailscale admin console — is the minibot machine online?
- If the machine lost power, `autorestart` should bring it back. If WiFi
  dropped, it should reconnect automatically. If the issue persists, consider
  wiring the Mac Mini via Ethernet for more reliable connectivity.

---

## Uninstalling

```bash
~/minibot/scripts/uninstall-launchagent-rustdesk.sh
~/minibot/scripts/uninstall-launchagent-caffeinate.sh
brew uninstall --cask rustdesk
mb-secrets delete RUSTDESK_PASSWORD
```
