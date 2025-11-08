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

# 5. Prune dead bookmarks
echo "[5/7] Pruning dead directory bookmarks..."
if [ -f "$SCRIPTS_DIR/g.sh" ]; then
  "$SCRIPTS_DIR/g.sh" prune --auto
else
  echo "  ⚠️  WARNING: g.sh not found, skipping bookmark pruning."
fi

# 6. Check AI Staff HQ Dispatchers
echo "[6/7] Checking AI Staff HQ dispatcher system..."
BIN_DIR="$HOME/dotfiles/bin"
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

# 7. Check .env configuration
echo "[7/7] Checking .env configuration for dispatchers..."
ENV_FILE="$HOME/dotfiles/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "  ⚠️  WARNING: .env file not found at $ENV_FILE. Dispatchers will not work without API keys."
elif [ ! -r "$ENV_FILE" ]; then
  echo "  ❌ ERROR: .env file is not readable."
  ERROR_COUNT=$((ERROR_COUNT + 1))
else
  # Check for required environment variables
  REQUIRED_VARS=("OPENROUTER_API_KEY" "DHP_TECH_MODEL" "DHP_CREATIVE_MODEL" "DHP_CONTENT_MODEL")
  for var in "${REQUIRED_VARS[@]}"; do
    if ! grep -q "^$var=" "$ENV_FILE"; then
      echo "  ⚠️  WARNING: Missing environment variable in .env: $var"
    fi
  done
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
