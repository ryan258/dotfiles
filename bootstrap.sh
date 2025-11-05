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

# 3. Create data directory and initialize data files
DATA_DIR="$HOME/.config/dotfiles-data"
echo "Setting up data directory at $DATA_DIR..."
mkdir -p "$DATA_DIR"

# Initialize data files only if they don't exist
DATA_FILES=("todo.txt" "todo_done.txt" "journal.txt" "health.txt" "dir_bookmarks" "dir_history" "dir_usage.log")
for file in "${DATA_FILES[@]}"; do
  FILE_PATH="$DATA_DIR/$file"
  if [ ! -f "$FILE_PATH" ]; then
    touch "$FILE_PATH"
    echo "  ✓ Created $file"
  else
    echo "  ✓ $file already exists"
  fi
done

# 4. Symlink dotfiles
echo "Symlinking dotfiles..."
symlink() {
  local source=$1
  local target=$2

  # Check if target is a symlink pointing to the correct location
  if [ -L "$target" ] && [ "$(readlink "$target")" == "$source" ]; then
    echo "  ✓ Symlink for $(basename "$target") already exists and is correct."
    return 0
  fi

  # Check if target exists but is not a symlink (e.g., a regular file)
  if [ -e "$target" ] && [ ! -L "$target" ] && [ "$FORCE" = false ]; then
    echo "  ⚠️  Warning: $(basename "$target") exists as a regular file (not a symlink)."
    echo "      Run with --force to replace it, or backup and remove it manually."
    return 1
  fi

  # Create or update the symlink
  ln -sf "$source" "$target"
  echo "  ✓ Created symlink for $(basename "$target")."
}
symlink "$(pwd)/zsh/.zshrc" "$HOME/.zshrc"
symlink "$(pwd)/zsh/.zprofile" "$HOME/.zprofile"
symlink "$(pwd)/zsh/aliases.zsh" "$HOME/.zsh_aliases"


echo "✅ Bootstrap complete!"
echo "Please restart your shell or run 'source ~/.zshrc'"
