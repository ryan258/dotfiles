#!/usr/bin/env bash
set -euo pipefail

# --- whatis.sh: Command and Alias Lookup Tool ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/lib/common.sh"
fi

if [ -z "$1" ]; then
  echo "Usage: whatis <command_or_alias>"
  exit 1
fi

SEARCH_TERM=$(sanitize_input "$1")
SEARCH_TERM=${SEARCH_TERM//$'\n'/ }

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ALIASES_FILE="$DOTFILES_DIR/zsh/aliases.zsh"
SCRIPTS_README="$DOTFILES_DIR/scripts/README.md"

echo "🔎 Searching for '$SEARCH_TERM'..."

# 1. Search in aliases file
if [ -f "$ALIASES_FILE" ]; then
  echo "--- Aliases ---"
  grep -i -F "alias $SEARCH_TERM=" "$ALIASES_FILE" || echo "No alias found."
fi

# 2. Search in scripts README
if [ -f "$SCRIPTS_README" ]; then
  echo "--- Script Descriptions ---"
  grep -i -F -C 1 -- "$SEARCH_TERM" "$SCRIPTS_README" || echo "No script description found."
fi
