#!/usr/bin/env bash
set -euo pipefail
hour=$(date +%H)
if [ "$hour" -lt 12 ]; then part="morning"
elif [ "$hour" -lt 18 ]; then part="afternoon"
else part="evening"; fi
echo "Good $part, $(whoami)."
# Optional quick context (silent if tools missing)
[ -x "$HOME/scripts/weather.sh" ] && "$HOME/scripts/weather.sh" || true
TODO_FILE="${TODO_FILE:-$HOME/.local/share/todo.txt}"
if [ -s "$TODO_FILE" ]; then
  echo
  echo "Top tasks:"
  nl -w2 -s'. ' "$TODO_FILE" | sed -n '1,5p'
fi
echo
echo 'Tip: add a note → journal.sh "Started: <thing>"'