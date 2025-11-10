#!/bin/bash
# unpacker.sh - Extracts any common archive type
set -euo pipefail

FILE=$1

if [ -z "$FILE" ]; then
   echo "Please provide a file to extract."
   echo "Usage: $0 <filename>"
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