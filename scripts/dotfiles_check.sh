#!/bin/bash
set -euo pipefail

# --- dotfiles_check.sh: System Validation Script ---

SCRIPTS_DIR="$(dirname "$0")"
PROJECT_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
BIN_DIR="$PROJECT_ROOT/bin"
STAFF_DIR="$PROJECT_ROOT/ai-staff-hq/staff"

echo "🩺 Running Dotfiles System Check..."

ERROR_COUNT=0
WARNING_COUNT=0

# 1. Check for executable scripts in scripts/
echo "[1/4] Checking scripts permissions..."
if [ -d "$SCRIPTS_DIR" ]; then
    while IFS= read -r script_path; do
        script_name=$(basename "$script_path")
        # skip this script itself and any hidden files
        if [[ "$script_name" == "dotfiles_check.sh" ]] || [[ "$script_name" == .* ]]; then
            continue
        fi
        
        if [ ! -x "$script_path" ]; then
            echo "  ❌ ERROR: Script is not executable: $script_name"
            ERROR_COUNT=$((ERROR_COUNT + 1))
        fi
    done < <(find "$SCRIPTS_DIR" -maxdepth 1 -name "*.sh")
else
     echo "  ❌ ERROR: Scripts directory not found at $SCRIPTS_DIR"
     ERROR_COUNT=$((ERROR_COUNT + 1))
fi

# 2. Check for data directory
echo "[2/4] Checking for data directory..."
DATA_DIR="$HOME/.config/dotfiles-data"
if [ ! -d "$DATA_DIR" ]; then
  echo "  ❌ ERROR: Data directory not found at $DATA_DIR"
  ERROR_COUNT=$((ERROR_COUNT + 1))
fi

# 3. Check for binary dependencies
DEPENDENCIES=("jq" "curl" "gawk" "osascript" "rclone")
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
  WARNING_COUNT=$((WARNING_COUNT + 1))
fi

# 5. Prune dead bookmarks
echo "[5/7] Pruning dead directory bookmarks..."
if [ -f "$SCRIPTS_DIR/g.sh" ]; then
  (
    source "$SCRIPTS_DIR/g.sh"
    if command -v prune_bookmarks >/dev/null 2>&1; then
        prune_bookmarks --auto >/dev/null 2>&1 || true
    elif command -v g >/dev/null 2>&1; then
        g prune --auto >/dev/null 2>&1 || true
    fi
  )
fi

# 6. Check AI Staff HQ Dispatchers (Dynamic Discovery)
echo "[6/7] Checking AI Staff HQ dispatcher system..."
if [ ! -d "$STAFF_DIR" ]; then
    echo "  ⚠️  WARNING: Staff directory not found at $STAFF_DIR. Skipping dispatcher check."
    WARNING_COUNT=$((WARNING_COUNT + 1))
else
    # Find all yaml files in staff directory
    while IFS= read -r yaml_file; do
        # Extract slug using awk (look for 'slug: value' pattern)
        # We use a simple grep/awk here to avoid heavy parsing, assuming standard formatting
        # OR || true to prevent set -e from killing script if grep misses
        slug=$(grep "^slug:" "$yaml_file" 2>/dev/null | head -n 1 | awk '{print $2}' | tr -d '"' | tr -d "'" || true)
        
        if [ -n "$slug" ]; then
            dispatcher_script="$BIN_DIR/dhp-${slug}.sh"
            
            if [ ! -f "$dispatcher_script" ]; then
                # Ensure we only warn once per missing dispatcher
                echo "  ⚠️  WARNING: Missing dispatcher for '$slug'"
                WARNING_COUNT=$((WARNING_COUNT + 1))
            elif [ ! -x "$dispatcher_script" ]; then
                echo "  ❌ ERROR: Dispatcher not executable: dhp-${slug}.sh"
                ERROR_COUNT=$((ERROR_COUNT + 1))
            fi
        fi
    done < <(find "$STAFF_DIR" -name "*.yaml")
fi


# 7. Validate .env configuration using validate_env.sh
echo "[7/7] Validating .env configuration..."
if [ -x "$SCRIPTS_DIR/validate_env.sh" ]; then
    if ! "$SCRIPTS_DIR/validate_env.sh" >/dev/null 2>&1; then
        # We silence output here as validate_env often prints its own specific errors
        echo "  ❌ ERROR: .env validation failed (run validate_env.sh for details)"
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
else
    echo "  ⚠️  WARNING: validate_env.sh missing or not executable"
    WARNING_COUNT=$((WARNING_COUNT + 1))
fi

# --- Summary ---
echo ""
echo "Summary:"
echo "  Errors:   $ERROR_COUNT"
echo "  Warnings: $WARNING_COUNT"
echo ""

if [ "$ERROR_COUNT" -eq 0 ]; then
  echo "✅ All systems functional!"
  exit 0
else
  echo "🔥 Critical issues found. Please review errors above."
  exit 1
fi