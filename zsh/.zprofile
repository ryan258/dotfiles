# PATH prepend helper to avoid duplicates
path_prepend() { [ -d "$1" ] || return 0; case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH";; esac }
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/dotfiles/scripts/bin"
export PATH
# Keep PATH updates at the end to override macOS path_helper.
