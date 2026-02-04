#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
DISPATCHER_BIN="$DOTFILES_DIR/bin"
SQUADS_FILE="${DHP_SQUADS_FILE:-$DOTFILES_DIR/ai-staff-hq/squads.json}"

print_usage() {
    echo "Usage: dispatch <squad> [--stream] [--temperature X] [--max-tokens N]" >&2
    echo "       cat file | dispatch <squad> [flags]" >&2
    exit 1
}

if [ $# -lt 1 ]; then
    print_usage
fi

TARGET="$1"
shift

if [ -x "$DISPATCHER_BIN/dhp-$TARGET.sh" ]; then
    exec "$DISPATCHER_BIN/dhp-$TARGET.sh" "$@"
fi

if [ -x "$DISPATCHER_BIN/$TARGET.sh" ]; then
    exec "$DISPATCHER_BIN/$TARGET.sh" "$@"
fi

if [ -f "$SQUADS_FILE" ]; then
    if jq -e --arg name "$TARGET" '.[$name].dispatcher' "$SQUADS_FILE" >/dev/null 2>&1; then
        dispatcher=$(jq -r --arg name "$TARGET" '.[$name].dispatcher' "$SQUADS_FILE")
        exec "$DISPATCHER_BIN/$dispatcher" "$@"
    fi
fi

echo "dispatch: unknown squad or dispatcher '$TARGET'" >&2
print_usage
