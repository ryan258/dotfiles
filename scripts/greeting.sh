#!/usr/bin/env bash
set -euo pipefail
hour=$(date +%H)
if [ "$hour" -lt 12 ]; then part="morning"
elif [ "$hour" -lt 18 ]; then part="afternoon"
else part="evening"; fi
echo "Good $part, $(whoami)."
# Optional quick context (silent if tools missing)
command -v weather.sh >/dev/null 2>&1 && weather.sh || true
TODO_FILE="${TODO_FILE:-$HOME/.config/dotfiles-data/todo.txt}"
if [ -s "$TODO_FILE" ]; then
  echo
  echo "Top tasks:"
  nl -w2 -s'. ' "$TODO_FILE" | sed -n '1,5p'
fi
echo
echo 'Tip: add a note → journal.sh "Started: <thing>"'