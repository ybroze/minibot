# Minibot Environment
# Add this to ~/.zshrc for the minibot user

# Ensure all new files are owner-only by default (rwx------)
umask 077

eval "$(/opt/homebrew/bin/brew shellenv)"

export MINIBOT_HOME="$HOME/minibot"
export PATH="$MINIBOT_HOME/bin:$HOME/.local/bin:$PATH"

# Prevent accidental system modifications
export HOMEBREW_NO_AUTO_UPDATE=1

# Clear environment of user-specific cruft
# unset HISTFILE  # Optional: disable shell history (uncomment if desired)

# Prompt indicator
export PS1="%F{cyan}[minibot]%f %~ %# "

# Helpful aliases
alias mb-build='~/minibot/scripts/build-openclaw.sh'
alias mb-start='~/minibot/bin/minibot-start.sh'
alias mb-stop='~/minibot/bin/minibot-stop.sh'
alias mb-logs='~/minibot/bin/minibot-logs.sh'
alias mb-status='docker compose -f ~/minibot/docker/docker-compose.yml ps'
alias mb-secrets='~/minibot/bin/minibot-secrets.sh'
