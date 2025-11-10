#!/bin/bash

validate_dependencies() {
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
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
