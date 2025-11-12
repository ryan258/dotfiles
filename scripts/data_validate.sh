#!/bin/bash
set -euo pipefail

DATA_DIR="$HOME/.config/dotfiles-data"
REQUIRED_ITEMS=(
  "todo.txt"
  "todo_done.txt"
  "journal.txt"
  "health.txt"
  "dir_bookmarks"
  "dir_history"
  "dir_usage.log"
  "system.log"
  "medications.txt" # Added medications.txt as a sensitive file
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
)

if [ ! -d "$DATA_DIR" ]; then
  echo "❌ Data directory missing: $DATA_DIR" >&2
  exit 1
fi

STATUS=0

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
    CURRENT_PERMS=$(stat -f %A "$path")
    if [ "$CURRENT_PERMS" != "600" ]; then
      echo "  ⚠️  WARNING: Sensitive file ($item) has insecure permissions ($CURRENT_PERMS). Should be 600." >&2
      # Do not increment STATUS to fail the script, as this is a warning.
      # User can decide to fix it.
    fi
  fi
done

if [ "$STATUS" -eq 0 ]; then
  echo "✅ Data files present and readable."
fi

exit "$STATUS"
