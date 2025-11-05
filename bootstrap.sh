#!/bin/bash
set -euo pipefail

# --- bootstrap.sh: New Machine Setup Script ---

FORCE=false
if [ "${1:-}" == "--force" ]; then
  FORCE=true
fi

echo "🚀 Bootstrapping new machine..."

# 1. Install Homebrew (if not installed)
if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "Homebrew already installed."
fi

# 2. Install dependencies
DEPENDENCIES=("jq" "curl" "gawk")
echo "Installing dependencies..."
for dep in "${DEPENDENCIES[@]}"; do
  if ! brew list "$dep" >/dev/null 2>&1 || [ "$FORCE" = true ]; then
    brew install "$dep"
  else
    echo "  $dep is already installed."
  fi
done

# 3. Create data directory
DATA_DIR="$HOME/.config/dotfiles-data"
echo "Creating data directory at $DATA_DIR..."
mkdir -p "$DATA_DIR"

# 4. Symlink dotfiles
echo "Symlinking dotfiles..."
symlink() {
  local source=$1
  local target=$2
  if [ -L "$target" ] && [ "$(readlink "$target")" == "$source" ] && [ "$FORCE" = false ]; then
    echo "  Symlink for $(basename "$target") already exists and is correct."
  else
    ln -sf "$source" "$target"
    echo "  Created symlink for $(basename "$target")."
  fi
}
symlink "$(pwd)/zsh/.zshrc" "$HOME/.zshrc"
symlink "$(pwd)/zsh/.zprofile" "$HOME/.zprofile"
symlink "$(pwd)/zsh/aliases.zsh" "$HOME/.zsh_aliases"


echo "✅ Bootstrap complete!"
echo "Please restart your shell or run 'source ~/.zshrc'"
