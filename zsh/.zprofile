# .zprofile: Executed at login.
# PATH modifications are now handled in ~/.zshenv to ensure they are
# available to all shell types, including non-interactive ones.

# Source the interactive config for login shells to unify environments
[ -f "$ZDOTDIR/.zshrc" ] && source "$ZDOTDIR/.zshrc"

# Keep this file for any future login-specific configurations.
# For example, starting a terminal multiplexer like tmux.
