#!/usr/bin/env bash
set -euo pipefail

# observer.sh - Dotfiles-to-Obsidian observer entrypoint.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/config.sh"
fi

OBSERVER_HELPER="${OBSERVER_HELPER:-$SCRIPT_DIR/observer.py}"

if [ ! -f "$OBSERVER_HELPER" ]; then
    echo "Error: observer helper not found: $OBSERVER_HELPER" >&2
    exit 3
fi

exec python3 "$OBSERVER_HELPER" "$@"

