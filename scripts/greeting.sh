#!/usr/bin/env bash
set -euo pipefail

# greeting.sh - Print a quick greeting, weather, and top tasks.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/lib/common.sh"
fi
if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/lib/config.sh"
else
  echo "Error: configuration library not found at $SCRIPT_DIR/lib/config.sh" >&2
  exit 1
fi

hour=$(date +%H)
if [ "$hour" -lt 12 ]; then part="morning"
elif [ "$hour" -lt 18 ]; then part="afternoon"
else part="evening"; fi
echo "Good $part, $(whoami)."
# Optional quick context (silent if tools missing)
command -v weather.sh >/dev/null 2>&1 && weather.sh || true
TODO_FILE="${TODO_FILE:?TODO_FILE is not set by config.sh}"
ensure_todo_migrated
if [ -s "$TODO_FILE" ]; then
  echo
  echo "Top tasks:"
  head -5 "$TODO_FILE" | awk -F'|' '{ printf "#%-3s %s\n", $1, $3 }'
fi
echo
echo 'Tip: add a note → journal.sh "Started: <thing>"'
