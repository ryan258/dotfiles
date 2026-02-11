#!/usr/bin/env bash
set -euo pipefail
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
if [ -s "$TODO_FILE" ]; then
  echo
  echo "Top tasks:"
  nl -w2 -s'. ' "$TODO_FILE" | sed -n '1,5p'
fi
echo
echo 'Tip: add a note → journal.sh "Started: <thing>"'
