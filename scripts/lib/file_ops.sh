#!/usr/bin/env bash
# Atomic file operations to prevent data loss
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_FILE_OPS_LOADED:-}" ]]; then
    return 0
fi
readonly _FILE_OPS_LOADED=true

# Atomic write: writes to temp file, then moves atomically
# Usage: atomic_write "content" "/path/to/file"
atomic_write() {
    local content="$1"
    local target="$2"
    local temp_file

    temp_file=$(mktemp "${target}.XXXXXX") || {
        echo "Error: Failed to create temp file for $target" >&2
        return 1
    }

    printf '%s' "$content" > "$temp_file" || {
        echo "Error: Failed to write to temp file" >&2
        rm -f "$temp_file"
        return 1
    }

    mv "$temp_file" "$target" || {
        echo "Error: Failed to move temp file to $target" >&2
        rm -f "$temp_file"
        return 1
    }

    return 0
}

# Atomic line prepend: prepends line to file atomically
# Usage: atomic_prepend "new line" "/path/to/file"
atomic_prepend() {
    local new_line="$1"
    local target="$2"
    local temp_file

    temp_file=$(mktemp "${target}.XXXXXX") || return 1
    { echo "$new_line"; cat "$target" 2>/dev/null; } > "$temp_file" || {
        rm -f "$temp_file"
        return 1
    }

    mv "$temp_file" "$target" || {
        rm -f "$temp_file"
        return 1
    }

    return 0
}

# Atomic line delete: removes line N from file atomically
# Usage: atomic_delete_line 5 "/path/to/file"
atomic_delete_line() {
    local line_num="$1"
    local target="$2"
    local temp_file

    temp_file=$(mktemp "${target}.XXXXXX") || return 1
    sed "${line_num}d" "$target" > "$temp_file" || {
        rm -f "$temp_file"
        return 1
    }

    mv "$temp_file" "$target" || {
        rm -f "$temp_file"
        return 1
    }

    return 0
}

# Atomic line replace: replaces line N in file atomically
# Usage: atomic_replace_line 5 "new content" "/path/to/file"
atomic_replace_line() {
    local line_num="$1"
    local new_content="$2"
    local target="$3"
    local temp_file

    temp_file=$(mktemp "${target}.XXXXXX") || return 1
    # Use awk for safe replacement (avoid sed regex/delimiter issues)
    awk -v line="$line_num" -v content="$new_content" 'NR == line { print content; next } { print }' "$target" > "$temp_file" || {
        rm -f "$temp_file"
        return 1
    }

    mv "$temp_file" "$target" || {
        rm -f "$temp_file"
        return 1
    }

    return 0
}
