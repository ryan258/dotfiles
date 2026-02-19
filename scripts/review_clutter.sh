#!/usr/bin/env bash
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
  if [ ! -d "$dir" ]; then
    echo "Directory not found, skipping: $dir"
    continue
  fi

  # Find files older than 30 days
  while IFS= read -r file; do
    echo ""
    echo "Found old file: $(basename "$file")"

    if [ -t 0 ] && [ -r /dev/tty ]; then
      printf "Action: (a)rchive, (d)elete, (s)kip? " > /dev/tty
      if ! IFS= read -r -n 1 REPLY < /dev/tty; then
        REPLY="s"
      fi
      printf "\n" > /dev/tty
    else
      REPLY="s"
      echo "Non-interactive session detected. Skipping by default."
    fi

    case $REPLY in
      a|A)
        ARCHIVE_DIR="$ARCHIVE_DIR_BASE/$(date +%Y-%m)"
        if [ "$DRY_RUN" = true ]; then
            echo "  Would archive $file to $ARCHIVE_DIR"
        else
            mkdir -p "$ARCHIVE_DIR"
            mv -- "$file" "$ARCHIVE_DIR/"
            echo "Archived to $ARCHIVE_DIR"
        fi
        ;;
      d|D)
        if [ "$DRY_RUN" = true ]; then
            echo "  Would delete $file"
        else
            rm -- "$file"
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
  done < <(find "$dir" -type f -mtime +30 2>/dev/null || true)
done

echo ""
echo "Clutter review complete."
