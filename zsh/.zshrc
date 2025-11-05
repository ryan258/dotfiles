# --- reserved names hardening (runs AFTER aliases load) ---
unalias env  2>/dev/null; unset -f env  2>/dev/null
unalias open 2>/dev/null; unset -f open 2>/dev/null

# safe replacements for your helpers
alias devenv='~/scripts/dev_shortcuts.sh env'
alias openf='~/scripts/open_file.sh'

# handy wrappers for the keychain tools
alias wk='with-keys'
alias wr='with-req --'
export PATH="$HOME/.composer/vendor/bin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"
export PATH="$HOME/.config/composer/vendor/bin:$PATH"

# fnm: fast node manager
eval "$(fnm env --shell zsh --use-on-cd)"

echo "SUCCESS! Dotfiles are loading."
source "$ZDOTDIR/aliases.zsh"
# source "$ZDOTDIR/.zsh_aliases"

# Run startday.sh once per day, persistently across reboots
LAST_RUN_FILE="$HOME/.config/dotfiles-data/.startday_last_run"
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
