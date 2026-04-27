#!/usr/bin/env bash
set -euo pipefail

# bash_graph.sh - Shell dependency graph wrapper for dotfiles.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1090
source "$SCRIPT_DIR/lib/common.sh"

BASH_GRAPH_HELPER="${BASH_GRAPH_HELPER:-$SCRIPT_DIR/bash_graph.py}"
BASH_GRAPH_ROOT="${BASH_GRAPH_ROOT:-$DOTFILES_DIR}"

usage() {
    cat <<'EOF'
Usage: bash_graph.sh <command> [args]

Commands:
  scan                         Print the full shell dependency graph as JSON
  sources <file>               List files sourced by a shell file
  dependents <file>            List files that source a shell file
  functions <symbol>           List function definitions for a symbol
  impact <symbol-or-file>      Summarize symbol or file blast radius

Environment:
  BASH_GRAPH_ROOT              Root to scan (defaults to dotfiles root)
  BASH_GRAPH_HELPER            Override parser helper for tests/debugging
EOF
}

fail_usage() {
    usage >&2
    exit "$EXIT_INVALID_ARGS"
}

require_helper() {
    require_cmd python3 "brew install python"

    if [[ ! -f "$BASH_GRAPH_HELPER" ]]; then
        echo "Error: bash graph helper not found: $BASH_GRAPH_HELPER" >&2
        exit "$EXIT_FILE_NOT_FOUND"
    fi
}

validated_root() {
    local root
    root=$(validate_safe_path "$BASH_GRAPH_ROOT" "$HOME") || {
        echo "Error: Invalid bash graph root: $BASH_GRAPH_ROOT" >&2
        exit "$EXIT_INVALID_ARGS"
    }

    if [[ ! -d "$root" ]]; then
        echo "Error: bash graph root not found: $root" >&2
        exit "$EXIT_FILE_NOT_FOUND"
    fi

    printf '%s\n' "$root"
}

main() {
    local command="${1:-}"
    local root

    [[ -n "$command" ]] || fail_usage
    shift || true

    case "$command" in
        -h|--help|help)
            usage
            ;;
        scan)
            [[ "$#" -eq 0 ]] || fail_usage
            require_helper
            root=$(validated_root)
            python3 "$BASH_GRAPH_HELPER" --root "$root" scan
            ;;
        sources|dependents|functions|impact)
            [[ "$#" -eq 1 ]] || fail_usage
            require_helper
            root=$(validated_root)
            python3 "$BASH_GRAPH_HELPER" --root "$root" "$command" "$1"
            ;;
        *)
            echo "Error: Unknown command: $command" >&2
            fail_usage
            ;;
    esac
}

main "$@"
