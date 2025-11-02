#!/bin/bash
set -euo pipefail

# --- dotfiles_check.sh: System Validation Script ---

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
)

SCRIPTS_DIR="$(dirname "$0")"

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

# --- Summary ---
echo ""
if [ $ERROR_COUNT -eq 0 ]; then
  echo "✅ All systems OK!"
  exit 0
else
  echo "🔥 Found $ERROR_COUNT critical error(s). Please fix the issues above."
  exit 1
fi
