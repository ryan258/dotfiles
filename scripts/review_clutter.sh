#!/bin/bash
set -euo pipefail

# --- review_clutter.sh: Interactive clutter review for Desktop and Downloads ---

DRY_RUN=false
if [ "${1:-}" == "--dry-run" ] || [ "${1:-}" == "-n" ]; then
  DRY_RUN=true
  echo "Performing a dry run. No files will be moved or deleted."
fi

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
        if [ "$DRY_RUN" = true ]; then
            echo "  Would archive $file to $ARCHIVE_DIR"
        else
            mkdir -p "$ARCHIVE_DIR"
            mv "$file" "$ARCHIVE_DIR/"
            echo "Archived to $ARCHIVE_DIR"
        fi
        ;;
      d|D)
        if [ "$DRY_RUN" = true ]; then
            echo "  Would delete $file"
        else
            rm "$file"
            echo "Deleted."
        fi
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
