# PATH prepend helper to avoid duplicates
path_prepend() { [ -d "$1" ] || return 0; case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH";; esac }
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/dotfiles/scripts"
path_prepend "$HOME/dotfiles/bin"
export PATH

# Set the default blog directory
export BLOG_DIR="${BLOG_DIR:-$HOME/Projects/my-ms-ai-blog}"

# Keep PATH updates at the end to override macOS path_helper.

# Source the interactive config for login shells to unify environments
[ -f "$ZDOTDIR/.zshrc" ] && source "$ZDOTDIR/.zshrc"
