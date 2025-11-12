#!/bin/bash
set -euo pipefail

# --- bootstrap.sh: New Machine Setup Script ---

# version_compare: Compares two version strings.
# Returns 0 if $1 >= $2, 1 otherwise.
version_compare() {
    if [ "$1" = "$2" ]; then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # Fill empty positions with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 0
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 1
        fi
    done
    return 0
}

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

# 6. Secure GitHub token file permissions
GITHUB_TOKEN_FILE="$HOME/.github_token"
if [ -f "$GITHUB_TOKEN_FILE" ]; then
    echo "Securing GitHub token file permissions..."
    chmod 600 "$GITHUB_TOKEN_FILE"
    echo "  ✓ Set permissions for $GITHUB_TOKEN_FILE to 600."
else
    echo "  GitHub token file ($GITHUB_TOKEN_FILE) not found. Skipping permission setup."
fi

# 7. Verify dependency versions
echo "Verifying dependency versions..."

# jq version check
JQ_MIN_VERSION="1.6"
if command -v jq >/dev/null 2>&1; then
    JQ_VERSION=$(jq --version | cut -d ' ' -f 2)
    if version_compare "$JQ_VERSION" "$JQ_MIN_VERSION"; then
        echo "  ✓ jq (version $JQ_VERSION) meets minimum requirement ($JQ_MIN_VERSION)."
    else
        echo "  ⚠️  Warning: jq version ($JQ_VERSION) is below recommended minimum ($JQ_MIN_VERSION). Please update jq." >&2
    fi
else
    echo "  ⚠️  Warning: jq not found. Please install jq." >&2
fi

# curl version check (basic check, more complex version parsing might be needed for specific features)
CURL_MIN_VERSION="7.64.0" # Version that supports --json flag, for example
if command -v curl >/dev/null 2>&1; then
    CURL_VERSION=$(curl --version | head -n 1 | cut -d ' ' -f 2)
    if version_compare "$CURL_VERSION" "$CURL_MIN_VERSION"; then
        echo "  ✓ curl (version $CURL_VERSION) meets minimum requirement ($CURL_MIN_VERSION)."
    else
        echo "  ⚠️  Warning: curl version ($CURL_VERSION) is below recommended minimum ($CURL_MIN_VERSION). Please update curl." >&2
    fi
else
    echo "  ⚠️  Warning: curl not found. Please install curl." >&2
fi

# gawk version check
GAWK_MIN_VERSION="5.0.0"
if command -v gawk >/dev/null 2>&1; then
    GAWK_VERSION=$(gawk --version | head -n 1 | cut -d ' ' -f 3)
    if version_compare "$GAWK_VERSION" "$GAWK_MIN_VERSION"; then
        echo "  ✓ gawk (version $GAWK_VERSION) meets minimum requirement ($GAWK_MIN_VERSION)."
    else
        echo "  ⚠️  Warning: gawk version ($GAWK_VERSION) is below recommended minimum ($GAWK_MIN_VERSION). Please update gawk." >&2
    fi
elif command -v awk >/dev/null 2>&1; then
    # Fallback to awk, but warn if gawk is preferred
    echo "  ⚠️  Warning: gawk not found, using awk instead. Some features may be limited." >&2
else
    echo "  ⚠️  Warning: awk/gawk not found. Please install gawk." >&2
fi


echo "✅ Bootstrap complete!"
echo "Please restart your shell or run 'source ~/.zshrc'"
