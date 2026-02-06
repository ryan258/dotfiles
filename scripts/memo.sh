#!/usr/bin/env bash
set -euo pipefail

# memo.sh - Legacy shortcut for cheatsheet output.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEATSHEET_SCRIPT="$SCRIPT_DIR/cheatsheet.sh"

if [ ! -x "$CHEATSHEET_SCRIPT" ]; then
    echo "Error: cheatsheet.sh not found or not executable at $CHEATSHEET_SCRIPT" >&2
    exit 1
fi

exec "$CHEATSHEET_SCRIPT" "$@"
