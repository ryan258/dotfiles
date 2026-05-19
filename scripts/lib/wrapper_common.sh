#!/usr/bin/env bash
# wrapper_common.sh - Shared helpers for sibling-product compatibility wrappers.
# NOTE: This file is SOURCED, not executed. Do not set -euo pipefail.
#
# Provides:
#   wrapper_truthy <value>          Return 0 if value is a truthy string.
#   wrapper_help_requested <args>   Return 0 if -h/--help/help appears in args.
#   wrapper_resolve_safe_path <p> <base?>
#                                   Echo a validated path or fall through
#                                   unchanged if validate_safe_path is absent.
#
# Each wrapper still owns its *_unavailable and *_daily_hook functions because
# daily-hook exit semantics differ by product (observer exits 0 silently;
# blog exits 3 so callers print a fallback line).

if [[ -n "${_WRAPPER_COMMON_LOADED:-}" ]]; then
    return 0
fi
readonly _WRAPPER_COMMON_LOADED=true

wrapper_truthy() {
    case "${1:-}" in
        true|TRUE|1|yes|YES|y|Y|on|ON)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

wrapper_help_requested() {
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

wrapper_resolve_safe_path() {
    local path="$1"
    local base="${2:-$HOME}"
    if command -v validate_safe_path >/dev/null 2>&1; then
        validate_safe_path "$path" "$base"
    else
        printf '%s' "$path"
    fi
}
