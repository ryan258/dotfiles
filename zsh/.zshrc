export PATH="$HOME/.composer/vendor/bin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"
export PATH="$HOME/.config/composer/vendor/bin:$PATH"

# fnm: fast node manager
if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --shell zsh --use-on-cd)"
fi

# Editor for spec templates
export EDITOR="code --wait"

# echo "SUCCESS! Dotfiles are loading."
source "$ZDOTDIR/aliases.zsh"
# Fabric-AI integrations (urlpost, ytpack, diffreview, etc.)
if [ -f "$ZDOTDIR/aliases/fabric-ai.zsh" ]; then
    source "$ZDOTDIR/aliases/fabric-ai.zsh"
fi

# Run startday.sh once per day, persistently across reboots
DOTFILES_DATA_ROOT="${XDG_DATA_HOME:-$HOME/.config}/dotfiles-data"
mkdir -p "$DOTFILES_DATA_ROOT"
LAST_RUN_FILE="$DOTFILES_DATA_ROOT/.startday_last_run"
TODAY=$(date +%Y-%m-%d)

# Check if the last run file exists and what date it contains
if [ -f "$LAST_RUN_FILE" ]; then
    LAST_RUN_DATE=$(cat "$LAST_RUN_FILE")
else
    LAST_RUN_DATE=""
fi

# If the last run date is not today, run the script
if [ "$LAST_RUN_DATE" != "$TODAY" ]; then
    bash "$HOME/dotfiles/scripts/startday.sh"
    # Update the last run file with today's date
    echo "$TODAY" > "$LAST_RUN_FILE"
fi

# --- Smart Navigation: Log directory changes for intelligent suggestions ---
USAGE_LOG="$DOTFILES_DATA_ROOT/dir_usage.log"

# Use zsh hook system to avoid conflicts
autoload -U add-zsh-hook
__ensure_private_usage_log() {
    mkdir -p "$(dirname "$USAGE_LOG")"
    if [ ! -f "$USAGE_LOG" ]; then
        : > "$USAGE_LOG"
    fi
    chmod 600 "$USAGE_LOG" 2>/dev/null || true
}

__log_directory_change() {
    # Log directory changes for smart navigation suggestions (used by g suggest)
    # Format: timestamp|directory
    __ensure_private_usage_log
    printf '%s|%s\n' "$(date +%s)" "$(pwd)" >> "$USAGE_LOG"
}
__ensure_private_usage_log
add-zsh-hook chpwd __log_directory_change

# Added by Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"

# KVOID Alias (Accessible Mode)
alias k="cd ${PROJECTS_DIR:-$HOME/Projects}/production-house_audio-plays--ambient-horror && uv run ./kvoid"
alias sm="${PROJECTS_DIR:-$HOME/Projects}/shadow_mirror/bin/shadow-mirror"

# Glowforge Image Processor
alias gf="${PROJECTS_DIR:-$HOME/Projects}/glowforge-it/gf"
