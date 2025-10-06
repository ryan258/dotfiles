# --- user PATHs ---
export PATH="$HOME/scripts:$PATH"
[[ ":$PATH:" == *":$HOME/bin:"* ]] || export PATH="$HOME/bin:$PATH"

# --- safely load aliases if syntax is OK ---
if command -v zsh >/dev/null 2>&1 && zsh -n "$HOME/.zsh_aliases" >/dev/null 2>&1; then
  source "$HOME/.zsh_aliases"
else
  [[ -f "$HOME/.zsh_aliases" ]] && echo "⚠️  Skipping ~/.zsh_aliases due to syntax errors."
fi

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
if [[ ! -f /tmp/startday_ran_today_$(date +%Y%m%d) ]]; then
    source "$HOME/dotfiles/scripts/startday.sh"
    touch /tmp/startday_ran_today_$(date +%Y%m%d)
fi