#!/bin/bash
# minibot-secrets.sh
# Manage Minibot secrets via the macOS Keychain.
#
# Usage:
#   minibot-secrets.sh set <KEY> [value]   Store a secret (prompts if value omitted)
#   minibot-secrets.sh get <KEY>           Retrieve a secret
#   minibot-secrets.sh delete <KEY>        Remove a secret
#   minibot-secrets.sh list                List required Minibot secret keys
#   minibot-secrets.sh export              Export all secrets as shell exports (for eval)
#   minibot-secrets.sh keys               Print required secret key names, one per line
#   minibot-secrets.sh generate <KEY|all>  Generate a random password and store it
#   minibot-secrets.sh init                Interactive first-time setup of required secrets
#
# Secrets are stored in the user's login keychain under the service name
# "minibot" with the account field set to the key name.

set -euo pipefail

SERVICE_NAME="minibot"

# All secrets that Minibot services require.
# Add new keys here as the project grows.
REQUIRED_SECRETS=(
    POSTGRES_PASSWORD
    REDIS_PASSWORD
    MONGO_PASSWORD
    OPENCLAW_GATEWAY_PASSWORD
)

usage() {
    echo "Usage: $(basename "$0") <command> [args]"
    echo ""
    echo "Commands:"
    echo "  set <KEY> [value]   Store a secret (prompts interactively if value omitted)"
    echo "  get <KEY>           Print a secret's value to stdout"
    echo "  delete <KEY>        Remove a secret from the keychain"
    echo "  list                List required Minibot secret keys in the keychain"
    echo "  export              Print 'export KEY=value' lines for eval"
    echo "  keys                Print required secret key names, one per line"
    echo "  generate <KEY|all>  Generate a random password and store it"
    echo "  init                Interactive first-time setup of all required secrets"
}

# --- helpers ----------------------------------------------------------------

_secret_exists() {
    security find-generic-password -s "$SERVICE_NAME" -a "$1" &>/dev/null
}

_get_secret() {
    # -w prints only the password value
    security find-generic-password -s "$SERVICE_NAME" -a "$1" -w 2>/dev/null
}

_set_secret() {
    local key="$1" value="$2"
    # Delete first if it already exists (update is not atomic in security(1))
    if _secret_exists "$key"; then
        security delete-generic-password -s "$SERVICE_NAME" -a "$key" &>/dev/null
    fi
    security add-generic-password -s "$SERVICE_NAME" -a "$key" -w "$value"
}

_delete_secret() {
    if _secret_exists "$1"; then
        security delete-generic-password -s "$SERVICE_NAME" -a "$1" &>/dev/null
        echo "Deleted: $1"
    else
        echo "Not found: $1"
    fi
}

_generate_password() {
    # 48 hex characters — no special characters, safe for URLs and connection strings.
    openssl rand -hex 24
}

# --- commands ---------------------------------------------------------------

cmd_set() {
    local key="${1:-}"
    local value="${2:-}"
    if [ -z "$key" ]; then
        echo "Error: KEY is required." >&2
        usage >&2
        exit 1
    fi
    if [ -z "$value" ]; then
        echo -n "Enter value for $key: "
        read -rs value
        echo ""
        if [ -z "$value" ]; then
            echo "Error: value cannot be empty."
            exit 1
        fi
    fi
    if [ ${#value} -lt 12 ]; then
        echo "  Warning: password is shorter than 12 characters." >&2
    fi
    _set_secret "$key" "$value"
    echo "✓ Stored $key in keychain (service: $SERVICE_NAME)"
}

cmd_get() {
    local key="${1:-}"
    if [ -z "$key" ]; then
        echo "Error: KEY is required." >&2
        usage >&2
        exit 1
    fi
    if ! _secret_exists "$key"; then
        echo "Error: $key not found in keychain." >&2
        exit 1
    fi
    _get_secret "$key"
}

cmd_delete() {
    local key="${1:-}"
    if [ -z "$key" ]; then
        echo "Error: KEY is required." >&2
        usage >&2
        exit 1
    fi
    _delete_secret "$key"
}

cmd_list() {
    echo "Minibot secrets in keychain:"
    for key in "${REQUIRED_SECRETS[@]}"; do
        if _secret_exists "$key"; then
            echo "  ✓ $key"
        else
            echo "  ✗ $key (not set)"
        fi
    done
}

cmd_export() {
    # Outputs lines suitable for: eval "$(minibot-secrets.sh export)"
    for key in "${REQUIRED_SECRETS[@]}"; do
        if _secret_exists "$key"; then
            local val
            val="$(_get_secret "$key")"
            printf 'export %s=%q\n' "$key" "$val"
        fi
    done
}

cmd_keys() {
    # Print required key names, one per line — used by other scripts to avoid
    # hardcoding the list in multiple places.
    printf '%s\n' "${REQUIRED_SECRETS[@]}"
}

cmd_generate() {
    local key="${1:-}"
    if [ -z "$key" ]; then
        echo "Error: KEY or 'all' is required." >&2
        usage >&2
        exit 1
    fi

    if [ "$key" = "all" ]; then
        for k in "${REQUIRED_SECRETS[@]}"; do
            if _secret_exists "$k"; then
                echo "  $k already exists — skipped."
            else
                local pw
                pw="$(_generate_password)"
                _set_secret "$k" "$pw"
                echo "  ✓ Generated and stored $k"
            fi
        done
    else
        if _secret_exists "$key"; then
            echo -n "$key already exists. Overwrite? (y/N): "
            read -r confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                echo "  Skipped."
                return
            fi
        fi
        local pw
        pw="$(_generate_password)"
        _set_secret "$key" "$pw"
        echo "✓ Generated and stored $key"
    fi
}

cmd_init() {
    echo "=== Minibot Secrets Setup ==="
    echo ""
    echo "This will store the following secrets in your macOS login keychain:"
    for key in "${REQUIRED_SECRETS[@]}"; do
        echo "  - $key"
    done
    echo ""

    for key in "${REQUIRED_SECRETS[@]}"; do
        if _secret_exists "$key"; then
            echo "$key already exists in keychain."
            echo -n "  Overwrite? (y/N): "
            read -r confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                echo "  Skipped."
                continue
            fi
        fi
        echo -n "Auto-generate $key? (Y/n): "
        read -r choice
        if [ "$choice" != "n" ] && [ "$choice" != "N" ]; then
            local pw
            pw="$(_generate_password)"
            _set_secret "$key" "$pw"
            echo "  ✓ Generated and stored."
        else
            echo -n "Enter value for $key: "
            read -rs value
            echo ""
            if [ -z "$value" ]; then
                echo "  Skipped (empty)."
                continue
            fi
            if [ ${#value} -lt 12 ]; then
                echo "  Warning: password is shorter than 12 characters." >&2
            fi
            _set_secret "$key" "$value"
            echo "  ✓ Stored."
        fi
    done

    echo ""
    echo "=== Done ==="
    echo "Verify with: $(basename "$0") list"
}

# --- dispatch ---------------------------------------------------------------

command="${1:-}"
shift || true

case "$command" in
    set)      cmd_set "$@" ;;
    get)      cmd_get "$@" ;;
    delete)   cmd_delete "$@" ;;
    list)     cmd_list ;;
    export)   cmd_export ;;
    keys)     cmd_keys ;;
    generate) cmd_generate "$@" ;;
    init)     cmd_init ;;
    -h|--help|"") usage ;;
    *)
        echo "Unknown command: $command" >&2
        usage >&2
        exit 1
        ;;
esac
