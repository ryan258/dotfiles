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

if [ $STATUS -eq 0 ]; then
  echo "✅ Data files present and readable."
fi

exit $STATUS
