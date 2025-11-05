#!/bin/bash
set -euo pipefail

# --- focus.sh: Set or display the focus for the day ---

FOCUS_FILE="$HOME/.config/dotfiles-data/daily_focus.txt"

case "${1:-show}" in
  show)
    if [ -f "$FOCUS_FILE" ]; then
      echo "🎯 Focus for Today: $(cat "$FOCUS_FILE")"
    else
      echo "No focus set for today. Set one with: focus \"Your focus\""
    fi
    ;;
  clear)
    rm -f "$FOCUS_FILE"
    echo "Focus for the day has been cleared."
    ;;
  *)
    echo "$*" > "$FOCUS_FILE"
    echo "Focus for today set to: $*"
    ;;
esac
