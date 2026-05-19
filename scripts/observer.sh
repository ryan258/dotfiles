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

if [ -f "$SCRIPT_DIR/lib/wrapper_common.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/wrapper_common.sh"
fi

observer_verbose_enabled() {
    wrapper_truthy "${OBSERVER_WRAPPER_VERBOSE:-${DOTFILES_DEBUG:-false}}"
}

observer_daily_hook() {
    wrapper_truthy "${OBSERVER_DAILY_HOOK:-false}"
}

# Daily-hook convention: observer's daily hook is fire-and-forget — the caller
# (startday.sh) discards stdout/stderr and ignores exit status, so a missing
# sibling is silent success (exit 0). Verbose mode prints the setup message.
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
    if wrapper_help_requested "$@"; then
        exit 0
    fi
    exit "${EXIT_FILE_NOT_FOUND:-3}"
}

PROJECTS_DIR="$(wrapper_resolve_safe_path "${PROJECTS_DIR:-$HOME/Projects}" "$HOME")" \
    || exit "${EXIT_INVALID_ARGS:-2}"

OBSERVER_HOME="$(wrapper_resolve_safe_path "${OBSERVER_HOME:-$PROJECTS_DIR/obsidian-observer}" "$HOME")" \
    || exit "${EXIT_INVALID_ARGS:-2}"

if [ -n "${OBSERVER_HELPER:-}" ]; then
    OBSERVER_HELPER="$(wrapper_resolve_safe_path "$OBSERVER_HELPER" "$HOME")" \
        || exit "${EXIT_INVALID_ARGS:-2}"
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
