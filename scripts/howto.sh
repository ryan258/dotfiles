#!/bin/bash
set -euo pipefail

# --- howto.sh: A personal, searchable how-to wiki ---

HOWTO_DIR="$HOME/.config/dotfiles-data/how-to"
mkdir -p "$HOWTO_DIR"

case "${1:-list}" in
  add)
    if [ -z "$2" ]; then
      echo "Usage: howto add <name>"
      exit 1
    fi
    if [ -z "${EDITOR:-}" ]; then
        echo "Error: EDITOR environment variable is not set."
        exit 1
    fi
    "$EDITOR" "$HOWTO_DIR/$2.txt"
    ;;

  search)
    if [ -z "$2" ]; then
      echo "Usage: howto search <term>"
      exit 1
    fi
    grep -i -r "$2" "$HOWTO_DIR"
    ;;

  list)
    echo "--- How-To Articles (most recent first) ---"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        find "$HOWTO_DIR" -maxdepth 1 -type f -name "*.txt" -exec stat -f '%m %N' {} \; | sort -rn | cut -d' ' -f2- | sed 's/\.txt$//' | sed 's#.*/##'
    else
        # Linux
        find "$HOWTO_DIR" -maxdepth 1 -type f -name "*.txt" -printf '%T@ %f\n' | sort -rn | cut -d' ' -f2- | sed 's/\.txt$//'
    fi
    ;;

  *)
    if [ -f "$HOWTO_DIR/$1.txt" ]; then
      cat "$HOWTO_DIR/$1.txt"
    else
      echo "Error: How-to '$1' not found."
      exit 1
    fi
    ;;
esac
