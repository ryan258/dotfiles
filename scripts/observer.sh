#!/usr/bin/env bash
set -euo pipefail

# observer.sh - Compatibility wrapper for the extracted Obsidian observer.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/config.sh"
fi

if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/common.sh"
fi

observer_truthy() {
    case "${1:-}" in
        true|TRUE|1|yes|YES|y|Y|on|ON)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

observer_verbose_enabled() {
    observer_truthy "${OBSERVER_WRAPPER_VERBOSE:-${DOTFILES_DEBUG:-false}}"
}

observer_help_requested() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            -h|--help|help)
                return 0
                ;;
        esac
    done
    return 1
}

observer_daily_hook() {
    observer_truthy "${OBSERVER_DAILY_HOOK:-false}"
}

observer_unavailable() {
    local expected_home="$1"
    local helper_path="$2"
    local message
    shift 2

    message="Obsidian observer is unavailable. Expected sibling repo: $expected_home. Missing helper: $helper_path. Install it there or set OBSERVER_HOME/OBSERVER_HELPER."

    if observer_daily_hook; then
        if observer_verbose_enabled; then
            echo "$message" >&2
        fi
        exit 0
    fi

    echo "$message" >&2
    if observer_help_requested "$@"; then
        exit 0
    fi
    exit "${EXIT_FILE_NOT_FOUND:-3}"
}

PROJECTS_DIR="${PROJECTS_DIR:-$HOME/Projects}"
if command -v validate_safe_path >/dev/null 2>&1; then
    PROJECTS_DIR="$(validate_safe_path "$PROJECTS_DIR" "$HOME")" || exit "${EXIT_INVALID_ARGS:-2}"
fi

OBSERVER_HOME="${OBSERVER_HOME:-$PROJECTS_DIR/obsidian-observer}"
if command -v validate_safe_path >/dev/null 2>&1; then
    OBSERVER_HOME="$(validate_safe_path "$OBSERVER_HOME" "$HOME")" || exit "${EXIT_INVALID_ARGS:-2}"
fi

if [ -n "${OBSERVER_HELPER:-}" ]; then
    if command -v validate_safe_path >/dev/null 2>&1; then
        OBSERVER_HELPER="$(validate_safe_path "$OBSERVER_HELPER" "$HOME")" || exit "${EXIT_INVALID_ARGS:-2}"
    fi
else
    OBSERVER_HELPER="$OBSERVER_HOME/scripts/observer.py"
fi

if [ ! -f "$OBSERVER_HELPER" ]; then
    observer_unavailable "$OBSERVER_HOME" "$OBSERVER_HELPER" "$@"
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is required. Install Python 3 and retry." >&2
    exit "${EXIT_SERVICE_ERROR:-5}"
fi

exec python3 "$OBSERVER_HELPER" "$@"
