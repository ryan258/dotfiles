#!/usr/bin/env bash
set -euo pipefail

# cyborg_scoped_site_check.sh - Compatibility wrapper for Cyborg site checks.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
CONFIG_LIB="$SCRIPT_DIR/lib/config.sh"
COMMON_LIB="$SCRIPT_DIR/lib/common.sh"

if [[ ! -f "$CONFIG_LIB" ]]; then
    echo "Error: required config library is missing: $CONFIG_LIB" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_LIB"

if [[ ! -f "$COMMON_LIB" ]]; then
    echo "Error: required common library is missing: $COMMON_LIB" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$COMMON_LIB"

cyborg_site_check_help_requested() {
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

cyborg_site_check_unavailable() {
    local message

    message="Cyborg scoped site check is unavailable. Expected sibling repo: $CYBORG_HOME. Missing helper: $CYBORG_SCOPED_SITE_CHECK. Install it there or set CYBORG_HOME/CYBORG_SCOPED_SITE_CHECK."
    echo "$message" >&2

    if cyborg_site_check_help_requested "$@"; then
        cyborg_site_check_usage
        exit 0
    fi
    exit "${EXIT_FILE_NOT_FOUND:-3}"
}

cyborg_site_check_usage() {
    echo "Usage: cyborg_scoped_site_check.sh content/path-one.md [content/path-two.md ...]" >&2
}

cyborg_site_check_validate_args() {
    if [[ "$#" -lt 1 ]]; then
        cyborg_site_check_usage
        exit "${EXIT_INVALID_ARGS:-2}"
    fi

    if cyborg_site_check_help_requested "$@"; then
        cyborg_site_check_usage
        exit 0
    fi

    local rel_path=""
    local sanitized=""
    CYBORG_SITE_CHECK_ARGS=()

    for rel_path in "$@"; do
        sanitized="$(sanitize_input "$rel_path")"
        if [[ -z "$sanitized" ]]; then
            echo "Scoped site check received an empty path." >&2
            exit "${EXIT_INVALID_ARGS:-2}"
        fi
        if [[ "$sanitized" != content/* ]]; then
            echo "Scoped site check only accepts content/ paths: $sanitized" >&2
            exit "${EXIT_INVALID_ARGS:-2}"
        fi
        if [[ "$sanitized" == *".."* ]]; then
            echo "Scoped site check path must not contain '..': $sanitized" >&2
            exit "${EXIT_INVALID_ARGS:-2}"
        fi
        CYBORG_SITE_CHECK_ARGS+=("$sanitized")
    done
}

PROJECTS_DIR="${PROJECTS_DIR:-$HOME/Projects}"
if command -v validate_safe_path >/dev/null 2>&1; then
    PROJECTS_DIR="$(validate_safe_path "$PROJECTS_DIR" "$HOME")" || exit "${EXIT_INVALID_ARGS:-2}"
fi

CYBORG_HOME="${CYBORG_HOME:-$PROJECTS_DIR/cyborg-agent}"
if command -v validate_safe_path >/dev/null 2>&1; then
    CYBORG_HOME="$(validate_safe_path "$CYBORG_HOME" "$HOME")" || exit "${EXIT_INVALID_ARGS:-2}"
fi

CYBORG_SCOPED_SITE_CHECK="${CYBORG_SCOPED_SITE_CHECK:-$CYBORG_HOME/scripts/cyborg_scoped_site_check.sh}"
if command -v validate_safe_path >/dev/null 2>&1; then
    CYBORG_SCOPED_SITE_CHECK="$(validate_safe_path "$CYBORG_SCOPED_SITE_CHECK" "$HOME")" || exit "${EXIT_INVALID_ARGS:-2}"
fi

if [[ ! -x "$CYBORG_SCOPED_SITE_CHECK" ]]; then
    cyborg_site_check_unavailable "$@"
fi

cyborg_site_check_validate_args "$@"

exec "$CYBORG_SCOPED_SITE_CHECK" "${CYBORG_SITE_CHECK_ARGS[@]}"
