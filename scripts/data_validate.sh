#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_lib "config.sh"

AUTO_FIX=false
FORMAT_CHECK=false

usage() {
  echo "Usage: $(basename "$0") [--fix] [--format]"
  echo "Validates presence, permissions, and (optionally) formats of dotfiles data."
  echo "  --fix     Automatically fix insecure file permissions (chmod 600)"
  echo "  --format  Validate file formats against canonical pipe-delimited rules"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --fix)
      AUTO_FIX=true
      shift
      ;;
    --format)
      FORMAT_CHECK=true
      shift
      ;;
    *)
      log_error "data_validate.sh unknown option '$1'" "data_validate.sh"
      echo "Error: Unknown option '$1'" >&2
      usage
      exit "$EXIT_INVALID_ARGS"
      ;;
  esac
done

REQUIRED_ITEMS=(
  "todo.txt"
  "todo_done.txt"
  "journal.txt"
  "health.txt"
  "dir_bookmarks"
  "dir_history"
  "dir_usage.log"
  "system.log"
  # medications.txt is optional
)

SENSITIVE_FILES=(
  "todo.txt"
  "todo_done.txt"
  "journal.txt"
  "health.txt"
  "dir_bookmarks"
  "dir_history"
  "dir_usage.log"
  "medications.txt"
  "clipboard_history.txt"
)

if [ ! -d "$DATA_DIR" ]; then
  die "Data directory missing: $DATA_DIR" "$EXIT_FILE_NOT_FOUND"
fi

STATUS=0

get_permissions() {
  local path="$1"
  if stat -f "%Lp" "$path" >/dev/null 2>&1; then
    stat -f "%Lp" "$path"
  else
    stat -c "%a" "$path" 2>/dev/null || echo ""
  fi
}

for item in "${REQUIRED_ITEMS[@]}"; do
  path="$DATA_DIR/$item"
  if [ ! -e "$path" ]; then
    echo "❌ Missing data file: $path" >&2
    STATUS=1
    continue
  fi

  if [ ! -r "$path" ]; then
    echo "❌ Data file is not readable: $path" >&2
    STATUS=1
    continue
  fi
done

echo "Checking permissions for sensitive data files..."
for item in "${SENSITIVE_FILES[@]}"; do
  path="$DATA_DIR/$item"
  if [ -f "$path" ]; then
    CURRENT_PERMS=$(get_permissions "$path")
    if [ -z "$CURRENT_PERMS" ]; then
      echo "  ⚠️  WARNING: Unable to determine permissions for $path" >&2
      STATUS=1
      continue
    fi
    if [ "$CURRENT_PERMS" != "600" ]; then
      if [ "$AUTO_FIX" = true ]; then
        echo "  ⚠️  WARNING: Sensitive file ($item) has insecure permissions ($CURRENT_PERMS). Auto-fixing..." >&2
        if ! chmod 600 "$path"; then
           echo "  ❌ ERROR: Failed to auto-fix permissions for $path" >&2
           STATUS=1
        fi
      else
        echo "  ⚠️  WARNING: Sensitive file ($item) has insecure permissions ($CURRENT_PERMS). Should be 600." >&2
        # Use --fix to automatically correct permissions.
      fi
    fi
  fi
done

if [ "$STATUS" -eq 0 ]; then
  echo "✅ Data files present and readable."
fi

validate_format() {
  local path="$1"
  local regex="$2"
  local label="$3"

  if [ ! -f "$path" ] || [ ! -s "$path" ]; then
    return 0
  fi

  local invalid_count
  invalid_count=$(awk -v re="$regex" 'NF && $0 !~ re {count++} END {print count+0}' "$path")

  if [ "$invalid_count" -gt 0 ]; then
    echo "❌ Format errors in $label ($invalid_count invalid lines)." >&2
    awk -v re="$regex" 'NF && $0 !~ re {print NR ":" $0}' "$path" | head -n 5 >&2
    STATUS=1
  fi
}

if [ "$FORMAT_CHECK" = true ]; then
  echo "Validating data file formats..."
  validate_format "$TODO_FILE" '^[0-9]{4}-[0-9]{2}-[0-9]{2}\\|.+$' "todo.txt"
  validate_format "$DONE_FILE" '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\\|.+$' "todo_done.txt"
  validate_format "$JOURNAL_FILE" '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\\|.+$' "journal.txt"
  validate_format "$HEALTH_FILE" '^[^|]+\\|[0-9]{4}-[0-9]{2}-[0-9]{2}([[:space:]]+[0-9]{2}:[0-9]{2}(:[0-9]{2})?)?\\|.*$' "health.txt"
  validate_format "$SPOON_LOG" '^(BUDGET\\|[0-9]{4}-[0-9]{2}-[0-9]{2}\\|[0-9]+|SPEND\\|[0-9]{4}-[0-9]{2}-[0-9]{2}\\|[0-9]{2}:[0-9]{2}\\|[0-9]+\\|.*)$' "spoons.txt"
  validate_format "$DATA_DIR/dir_bookmarks" '^[^|]+\\|[^|]+\\|.*$' "dir_bookmarks"
  validate_format "$DATA_DIR/dir_history" '^[0-9]{9,}\\|.+$' "dir_history"
  validate_format "$DATA_DIR/dir_usage.log" '^[0-9]{9,}\\|.+$' "dir_usage.log"
  validate_format "$DATA_DIR/favorite_apps" '^[^|]+\\|.+$' "favorite_apps"
  validate_format "$CLIPBOARD_FILE" '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\\|[^|]+\\|.*$' "clipboard_history.txt"
fi

exit "$STATUS"
