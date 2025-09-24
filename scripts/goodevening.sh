#!/usr/bin/env bash
set -euo pipefail
echo "=== Evening Wrap — $(date '+%Y-%m-%d %H:%M') ==="
# Show remaining tasks if any
if [ -x "$HOME/scripts/todo.sh" ]; then
  echo
  echo "Open tasks:"
  "$HOME/scripts/todo.sh" list || true
fi
# Show git status if inside a repo
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo
  echo "Git status:"
  git status --short
fi
echo
echo 'Tip: journal EOD → journal.sh "EOD: progress, blockers, tomorrow"'
