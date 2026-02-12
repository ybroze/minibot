# OpenClaw Experimental Environment
# Add this to ~/.zshrc for the openclaw user

export OPENCLAW_HOME="$HOME/openclaw"
export PATH="$OPENCLAW_HOME/bin:$HOME/.local/bin:$PATH"

# Prevent accidental system modifications
export HOMEBREW_NO_AUTO_UPDATE=1

# Clear environment of user-specific cruft
# unset HISTFILE  # Optional: disable shell history (uncomment if desired)

# Prompt indicator
export PS1="%F{cyan}[openclaw]%f %~ %# "

# Helpful aliases
alias oc-start='~/openclaw/bin/openclaw-start.sh'
alias oc-stop='~/openclaw/bin/openclaw-stop.sh'
alias oc-logs='~/openclaw/bin/openclaw-logs.sh'
alias oc-status='docker-compose -f ~/openclaw/docker/docker-compose.yml ps'
