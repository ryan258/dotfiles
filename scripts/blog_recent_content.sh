#!/usr/bin/env bash
# blog_recent_content.sh - Compatibility wrapper for Blog Factory recent content.
set -euo pipefail

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

blog_factory_recent_daily_hook() {
    wrapper_truthy "${BLOG_FACTORY_DAILY_HOOK:-false}"
}

blog_factory_recent_verbose_enabled() {
    wrapper_truthy "${BLOG_FACTORY_WRAPPER_VERBOSE:-${DOTFILES_DEBUG:-false}}"
}

# Daily-hook convention: see scripts/blog.sh — callers render their own
# fallback line, so missing sibling exits with EXIT_FILE_NOT_FOUND (quiet by
# default, verbose when BLOG_FACTORY_WRAPPER_VERBOSE=true).
blog_factory_recent_unavailable() {
    local expected_home="$1"
    local helper_path="$2"
    local message
    shift 2

    message="Blog Factory recent-content helper is unavailable. Expected sibling repo: $expected_home. Missing helper: $helper_path. Install it there or set BLOG_FACTORY_HOME/BLOG_FACTORY_RECENT_HELPER."

    if blog_factory_recent_daily_hook; then
        if blog_factory_recent_verbose_enabled; then
            echo "$message" >&2
        fi
        exit "${EXIT_FILE_NOT_FOUND:-3}"
    fi

    echo "$message" >&2

    if wrapper_help_requested "$@"; then
        exit 0
    fi
    exit "${EXIT_FILE_NOT_FOUND:-3}"
}

PROJECTS_DIR="$(wrapper_resolve_safe_path "${PROJECTS_DIR:-$HOME/Projects}" "$HOME")" \
    || exit "${EXIT_INVALID_ARGS:-2}"

BLOG_FACTORY_HOME="$(wrapper_resolve_safe_path "${BLOG_FACTORY_HOME:-$PROJECTS_DIR/blog-factory}" "$HOME")" \
    || exit "${EXIT_INVALID_ARGS:-2}"

if [ -n "${BLOG_FACTORY_RECENT_HELPER:-}" ]; then
    BLOG_FACTORY_RECENT_HELPER="$(wrapper_resolve_safe_path "$BLOG_FACTORY_RECENT_HELPER" "$HOME")" \
        || exit "${EXIT_INVALID_ARGS:-2}"
else
    BLOG_FACTORY_RECENT_HELPER="$BLOG_FACTORY_HOME/scripts/blog_recent_content.sh"
fi

if [ ! -f "$BLOG_FACTORY_RECENT_HELPER" ]; then
    blog_factory_recent_unavailable "$BLOG_FACTORY_HOME" "$BLOG_FACTORY_RECENT_HELPER" "$@"
fi

exec bash "$BLOG_FACTORY_RECENT_HELPER" "$@"
