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

# run startday.sh once per day
STARTDAY_MARK="/tmp/startday_ran_today_$(date +%Y%m%d)"
if [[ ! -f "$STARTDAY_MARK" ]]; then
    bash "$HOME/dotfiles/scripts/startday.sh"
    touch "$STARTDAY_MARK"
fi
