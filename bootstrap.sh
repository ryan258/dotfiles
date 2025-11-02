#!/bin/bash
set -euo pipefail

# --- bootstrap.sh: New Machine Setup Script ---

echo "🚀 Bootstrapping new machine..."

# 1. Install Homebrew (if not installed)
if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "Homebrew already installed."
fi

# 2. Install dependencies from Brewfile
# For now, we will manually list the dependencies here.
# In the future, we can use a Brewfile.
DEPENDENCIES=("jq" "curl" "gawk")
echo "Installing dependencies..."
for dep in "${DEPENDENCIES[@]}"; do
  if ! brew list "$dep" >/dev/null 2>&1; then
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
# This is a placeholder. In a real scenario, you would
# have a more robust symlinking strategy.
echo "Symlinking dotfiles..."
ln -sf "$(pwd)/zsh/.zshrc" "$HOME/.zshrc"
ln -sf "$(pwd)/zsh/.zprofile" "$HOME/.zprofile"
ln -sf "$(pwd)/zsh/aliases.zsh" "$HOME/.zsh_aliases"


echo "✅ Bootstrap complete!"
echo "Please restart your shell or run 'source ~/.zshrc'"
