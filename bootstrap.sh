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

# 4. Configure Zsh environment
echo "Configuring Zsh environment..."
ZSHENV_FILE="$HOME/.zshenv"
ZDOTDIR_LINE="export ZDOTDIR=\"$HOME/dotfiles/zsh\""
PATH_LINE_SCRIPTS="export PATH=\"$HOME/dotfiles/scripts:\$PATH\""
PATH_LINE_BIN="export PATH=\"$HOME/dotfiles/bin:\$PATH\""
PATH_LINE_LOCAL_BIN="export PATH=\"$HOME/.local/bin:\$PATH\""

# Create or update .zshenv file
if [ -f "$ZSHENV_FILE" ]; then
    # If file exists, check and add lines if they are missing
    grep -qF -- "$ZDOTDIR_LINE" "$ZSHENV_FILE" || echo "$ZDOTDIR_LINE" >> "$ZSHENV_FILE"
    grep -qF -- "$PATH_LINE_SCRIPTS" "$ZSHENV_FILE" || echo "$PATH_LINE_SCRIPTS" >> "$ZSHENV_FILE"
    grep -qF -- "$PATH_LINE_BIN" "$ZSHENV_FILE" || echo "$PATH_LINE_BIN" >> "$ZSHENV_FILE"
    grep -qF -- "$PATH_LINE_LOCAL_BIN" "$ZSHENV_FILE" || echo "$PATH_LINE_LOCAL_BIN" >> "$ZSHENV_FILE"
    echo "  ✓ .zshenv already exists, ensured configuration is present."
else
    # If file doesn't exist, create it with all necessary exports
    echo "$ZDOTDIR_LINE" > "$ZSHENV_FILE"
    echo "$PATH_LINE_SCRIPTS" >> "$ZSHENV_FILE"
    echo "$PATH_LINE_BIN" >> "$ZSHENV_FILE"
    echo "$PATH_LINE_LOCAL_BIN" >> "$ZSHENV_FILE"
    echo "  ✓ Created .zshenv and configured ZDOTDIR and PATH."
fi

# 5. Symlink other necessary configurations (if any)
# echo "Symlinking other dotfiles..."
# Example: symlink "$(pwd)/git/.gitconfig" "$HOME/.gitconfig"


echo "✅ Bootstrap complete!"
echo "Please restart your shell or run 'source ~/.zshrc'"
