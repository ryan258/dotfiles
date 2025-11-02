#!/bin/bash
set -euo pipefail

# --- whatis.sh: Command and Alias Lookup Tool ---

if [ -z "$1" ]; then
  echo "Usage: whatis <command_or_alias>"
  exit 1
fi

SEARCH_TERM="$1"
ALIASES_FILE="$HOME/dotfiles/zsh/aliases.zsh"
SCRIPTS_README="$HOME/dotfiles/scripts/README.md"

echo "🔎 Searching for '$SEARCH_TERM'..."

# 1. Search in aliases file
if [ -f "$ALIASES_FILE" ]; then
  echo "--- Aliases ---"
  grep -i "alias $SEARCH_TERM=" "$ALIASES_FILE" || echo "No alias found."
fi

# 2. Search in scripts README
if [ -f "$SCRIPTS_README" ]; then
  echo "--- Script Descriptions ---"
  grep -i -C 1 "$SEARCH_TERM" "$SCRIPTS_README" || echo "No script description found."
fi
