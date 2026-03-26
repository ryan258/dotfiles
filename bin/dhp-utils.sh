#!/usr/bin/env bash
# dhp-utils.sh: Utility functions for AI dispatchers
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_DHP_UTILS_LOADED:-}" ]]; then
    return 0
fi
readonly _DHP_UTILS_LOADED=true

# Callers should source common.sh before dhp-utils.sh if they want helpers like
# require_cmd(). validate_dependencies degrades gracefully when those helpers
# are unavailable.

# Validate required commands are available
# Usage: validate_dependencies curl jq python3
validate_dependencies() {
    for cmd in "$@"; do
        # Use common library if available
        if type require_cmd &>/dev/null; then
            require_cmd "$cmd" || return 1
        elif ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: '$cmd' is not installed. Please install it." >&2
            return 1
        fi
    done
}

ensure_api_key() {
    local key_var="${1:-OPENROUTER_API_KEY}"
    local value="${!key_var:-}"
    if [ -z "$value" ]; then
        echo "Error: $key_var is not set." >&2
        return 1
    fi
}

default_output_dir() {
    local fallback="$1"
    local var_name="$2"
    local value="${!var_name:-}"
    if [ -n "$value" ]; then
        echo "$value"
    else
        echo "$fallback"
    fi
}

read_dispatcher_input() {
    if [ -t 0 ]; then
        printf "%s" "$*"
    else
        cat
    fi
}

export -f validate_dependencies
export -f ensure_api_key
export -f default_output_dir
export -f read_dispatcher_input
