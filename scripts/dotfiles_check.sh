#!/bin/bash
set -euo pipefail

# --- dotfiles_check.sh: System Validation Script ---

SCRIPTS_DIR="$(dirname "$0")"

echo "🩺 Running Dotfiles System Check..."

ERROR_COUNT=0

# 1. Check for key script files
KEY_SCRIPTS=(
  "app_launcher.sh"
  "backup_project.sh"
  "blog.sh"
  "cheatsheet.sh"
  "clipboard_manager.sh"
  "dev_shortcuts.sh"
  "done.sh"
  "goodevening.sh"
  "health.sh"
  "journal.sh"
  "meds.sh"
  "my_progress.sh"
  "startday.sh"
  "status.sh"
  "todo.sh"
  "validate_env.sh" # Add validate_env.sh to key scripts
)

echo "[1/4] Checking for key scripts in $SCRIPTS_DIR..."
for script in "${KEY_SCRIPTS[@]}"; do
  if [ ! -f "$SCRIPTS_DIR/$script" ]; then
    echo "  ❌ ERROR: Missing script: $script"
    ERROR_COUNT=$((ERROR_COUNT + 1))
  fi
done

# 2. Check for data directory
echo "[2/4] Checking for data directory..."
DATA_DIR="$HOME/.config/dotfiles-data"
if [ ! -d "$DATA_DIR" ]; then
  echo "  ❌ ERROR: Data directory not found at $DATA_DIR"
  ERROR_COUNT=$((ERROR_COUNT + 1))
fi

# 3. Check for binary dependencies
DEPENDENCIES=("jq" "curl" "gawk" "osascript")
echo "[3/4] Checking for binary dependencies in PATH..."
for cmd in "${DEPENDENCIES[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "  ❌ ERROR: Command not found in PATH: $cmd"
    ERROR_COUNT=$((ERROR_COUNT + 1))
  fi
done

# 4. Check for GitHub token
echo "[4/4] Checking for GitHub token..."
GITHUB_TOKEN_FILE="$HOME/.github_token"
if [ ! -f "$GITHUB_TOKEN_FILE" ]; then
  echo "  ⚠️  WARNING: GitHub token not found at $GITHUB_TOKEN_FILE. Some features like project listing will fail."
  # This is a warning, not a critical error, so we don't increment ERROR_COUNT
fi

# 5. Prune dead bookmarks
echo "[5/7] Pruning dead directory bookmarks..."
if [ -f "$SCRIPTS_DIR/g.sh" ]; then
  # g.sh is a library, so we source it in a subshell to run the prune command
  (
    source "$SCRIPTS_DIR/g.sh"
    # Check if the function exists before calling
    if command -v prune_bookmarks >/dev/null 2>&1; then
        prune_bookmarks --auto
    elif command -v g >/dev/null 2>&1; then
        g prune --auto
    else
        # If g.sh was just aliases, maybe it doesn't expose a command we can run easily script-side.
        # But assuming the user intends to prune:
        echo "  ⚠️  Unable to run 'g prune' from check script."
    fi
  ) || echo "  ⚠️  Bookmark pruning failed (non-critical)"
else
  echo "  ⚠️  WARNING: g.sh not found, skipping bookmark pruning."
fi

# 6. Check AI Staff HQ Dispatchers
echo "[6/7] Checking AI Staff HQ dispatcher system..."
BIN_DIR="$SCRIPTS_DIR/../bin"
if [ ! -d "$BIN_DIR" ]; then
  echo "  ⚠️  WARNING: bin/ directory not found at $BIN_DIR. Dispatcher system not installed."
else
  DISPATCHERS=(
    "dhp-tech.sh"
    "dhp-creative.sh"
    "dhp-content.sh"
    "dhp-strategy.sh"
    "dhp-brand.sh"
    "dhp-market.sh"
    "dhp-stoic.sh"
    "dhp-research.sh"
    "dhp-narrative.sh"
    "dhp-copy.sh"
  )
  dispatcher_count=0
  for dispatcher in "${DISPATCHERS[@]}"; do
    if [ ! -f "$BIN_DIR/$dispatcher" ]; then
      echo "  ⚠️  WARNING: Missing optional dispatcher: $dispatcher"
    elif [ ! -x "$BIN_DIR/$dispatcher" ]; then
      echo "  ❌ ERROR: Dispatcher not executable: $dispatcher"
      ERROR_COUNT=$((ERROR_COUNT + 1))
    else
      dispatcher_count=$((dispatcher_count + 1))
    fi
  done
  echo "  ✅ Found $dispatcher_count/10 dispatchers"
fi

# 7. Validate .env configuration using validate_env.sh
echo "[7/7] Validating .env configuration..."
if ! "$SCRIPTS_DIR/validate_env.sh"; then
  ERROR_COUNT=$((ERROR_COUNT + 1))
fi

# --- Summary ---
echo ""
if [ "$ERROR_COUNT" -eq 0 ]; then
  echo "✅ All systems OK!"
  exit 0
else
  echo "🔥 Found $ERROR_COUNT critical error(s). Please fix the issues above."
  exit 1
fi