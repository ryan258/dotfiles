#!/bin/bash
# dhp-utils.sh: Utility functions for AI dispatchers

# Try to source common library for shared functions
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
if [[ -f "$DOTFILES_DIR/scripts/lib/common.sh" ]]; then
    source "$DOTFILES_DIR/scripts/lib/common.sh"
fi

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

# validate_path: Canonicalizes a path and checks if it's within the user's home directory.
# Usage: validate_path <path>
# Returns: 0 on success (prints canonicalized path), 1 on failure (prints error)
validate_path() {
    local input_path="$1"
    if [ -z "$input_path" ]; then
        echo "Error: validate_path requires a path argument." >&2
        return 1
    fi

    # Canonicalize the path
    local canonical_path
    canonical_path=$(python3 - "$input_path" <<'PY'
import os
import sys

print(os.path.realpath(sys.argv[1]))
PY
    2>/dev/null)

    if [ -z "$canonical_path" ]; then
        echo "Error: Cannot canonicalize path: '$input_path'" >&2
        return 1
    fi

    # Ensure the path is within the user's home directory
    if [ "$canonical_path" != "$HOME" ] && [[ "$canonical_path" != "$HOME"/* ]]; then
        echo "Error: Path '$canonical_path' is outside the allowed home directory." >&2
        return 1
    fi

    echo "$canonical_path"
    return 0
}

export -f validate_dependencies
export -f ensure_api_key
export -f default_output_dir
export -f read_dispatcher_input
export -f validate_path
