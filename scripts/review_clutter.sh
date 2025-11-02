#!/bin/bash
set -euo pipefail

# --- review_clutter.sh: Interactive clutter review for Desktop and Downloads ---

CLUTTER_DIRS=("$HOME/Desktop" "$HOME/Downloads")
ARCHIVE_DIR_BASE="$HOME/Documents/Archives"

for dir in "${CLUTTER_DIRS[@]}"; do
  echo "🔎 Reviewing clutter in $dir..."
  # Find files older than 30 days
  find "$dir" -type f -mtime +30 | while read -r file; do
    echo ""
    echo "Found old file: $(basename "$file")"
    read -p "Action: (a)rchive, (d)elete, (s)kip? " -n 1 -r
    echo ""

    case $REPLY in
      a|A)
        ARCHIVE_DIR="$ARCHIVE_DIR_BASE/$(date +%Y-%m)"
        mkdir -p "$ARCHIVE_DIR"
        mv "$file" "$ARCHIVE_DIR/"
        echo "Archived to $ARCHIVE_DIR"
        ;;
      d|D)
        rm "$file"
        echo "Deleted."
        ;;
      s|S)
        echo "Skipped."
        ;;
      *)
        echo "Invalid option. Skipped."
        ;;
    esac
  done
done

echo ""
echo "Clutter review complete."
