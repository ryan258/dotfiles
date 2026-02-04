#!/usr/bin/env bash
set -euo pipefail

# --- howto.sh: A personal, searchable how-to wiki ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/lib/common.sh"
fi

DATA_DIR="${DATA_DIR:-$HOME/.config/dotfiles-data}"
HOWTO_DIR="${HOWTO_DIR:-$DATA_DIR/how-to}"
HOWTO_DIR=$(validate_path "$HOWTO_DIR") || exit 1
mkdir -p "$HOWTO_DIR"

validate_howto_name() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Error: Name is required." >&2
    exit 1
  fi
  if ! [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Error: Name can only contain letters, numbers, '.', '_' and '-'." >&2
    exit 1
  fi
}

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
    name=$(sanitize_input "$2")
    name=${name//$'\n'/ }
    validate_howto_name "$name"
    file_path="$HOWTO_DIR/$name.txt"
    file_path=$(validate_path "$file_path") || exit 1
    if [[ "$file_path" != "$HOWTO_DIR/"* ]]; then
      echo "Error: Invalid file path." >&2
      exit 1
    fi
    "$EDITOR" "$file_path"
    ;;

  search)
    if [ -z "$2" ]; then
      echo "Usage: howto search <term>"
      exit 1
    fi
    term=$(sanitize_input "$2")
    term=${term//$'\n'/ }
    grep -i -r -- "$term" "$HOWTO_DIR"
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
    name=$(sanitize_input "$1")
    name=${name//$'\n'/ }
    validate_howto_name "$name"
    file_path="$HOWTO_DIR/$name.txt"
    file_path=$(validate_path "$file_path") || exit 1
    if [[ "$file_path" != "$HOWTO_DIR/"* ]]; then
      echo "Error: Invalid file path." >&2
      exit 1
    fi
    if [ -f "$file_path" ]; then
      cat "$file_path"
    else
      echo "Error: How-to '$1' not found."
      exit 1
    fi
    ;;
esac
