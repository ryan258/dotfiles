#!/usr/bin/env bash
# unpacker.sh - Extracts any common archive type
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
   # shellcheck disable=SC1090
   source "$SCRIPT_DIR/lib/common.sh"
fi

FILE_RAW="${1:-}"
FILE=$(sanitize_input "$FILE_RAW")
FILE=${FILE//$'\n'/ }
if [ -n "$FILE" ]; then
  FILE=$(validate_path "$FILE") || exit 1
fi

if [ -z "$FILE" ]; then
   echo "Please provide a file to extract."
   echo "Usage: $0 <filename>"
   exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "File not found: $FILE"
  exit 1
fi

echo "Extracting $FILE..."

case "$FILE" in
  *.tar.gz|*.tgz) tar -xzvf "$FILE" ;;
  *.zip)          unzip "$FILE"      ;;
  *.rar)          unrar x "$FILE"    ;;
  *.7z)           7z x "$FILE"       ;;
  *)              echo "'$FILE' is not a recognized archive type." ;;
esac

echo "Extraction complete."

# ---
