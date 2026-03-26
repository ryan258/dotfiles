#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
source "$DOTFILES_DIR/bin/dhp-shared.sh"

print_usage() {
    echo "Usage: dispatch <dispatcher> [--stream] [--temperature X]" >&2
    echo "       cat file | dispatch <dispatcher> [flags]" >&2
    exit 1
}

if [ $# -lt 1 ]; then
    print_usage
fi

TARGET="${1:-}"
shift

RESOLVED_CMD="$(dhp_resolve_dispatcher_command "$TARGET" "$DOTFILES_DIR" 2>/dev/null || true)"
if [ -n "$RESOLVED_CMD" ]; then
    exec "$RESOLVED_CMD" "$@"
fi

echo "dispatch: unknown dispatcher '$TARGET'" >&2
print_usage
