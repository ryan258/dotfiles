#!/usr/bin/env bash
# scripts/lib/context_capture.sh
# Shared library for context preservation
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_CONTEXT_CAPTURE_LOADED:-}" ]]; then
    return 0
fi
readonly _CONTEXT_CAPTURE_LOADED=true

# Dependencies:
# - DATA_DIR must be set by sourcing config.sh in the caller.
# - sanitize_input (optional) comes from common.sh if caller sourced it.
if [[ -z "${DATA_DIR:-}" ]]; then
    echo "Error: DATA_DIR is not set. Source scripts/lib/config.sh before context_capture.sh." >&2
    return 1
fi

CONTEXT_ROOT="${CONTEXT_ROOT:-}"
if [[ -z "$CONTEXT_ROOT" ]]; then
    echo "Error: CONTEXT_ROOT is not set. Source scripts/lib/config.sh before context_capture.sh." >&2
    return 1
fi

mkdir -p "$CONTEXT_ROOT"

_context_validate_name() {
    local raw_name="$1"
    local sanitized_name="$raw_name"

    if command -v sanitize_input >/dev/null 2>&1; then
        sanitized_name=$(sanitize_input "$raw_name")
    fi

    # Reject names that would be modified by sanitization.
    if [[ "$sanitized_name" != "$raw_name" ]]; then
        echo "Error: Context name contains unsupported characters." >&2
        return 1
    fi

    # Strict allowlist for safe filesystem names.
    if [[ ! "$raw_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "Error: Invalid context name. Use only letters, numbers, dot, underscore, and dash." >&2
        return 1
    fi

    return 0
}

# Capture the current working context
# Usage: capture_current_context [name]
capture_current_context() {
    local name="${1:-auto-$(date +%Y%m%d-%H%M)}"

    _context_validate_name "$name" || return 1

    local ctx_dir="$CONTEXT_ROOT/$name"
    
    if [ -d "$ctx_dir" ]; then
        echo "Updating existing context '$name'..."
    else
        echo "Creating new context '$name'..."
        mkdir -p "$ctx_dir"
    fi
    
    # 1. Metadata
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$ctx_dir/timestamp.txt"
    pwd > "$ctx_dir/directory.txt"
    
    # 2. Git State
    capture_git_state > "$ctx_dir/git_state.txt"
    
    # 3. Open Files (VS Code / Editors)
    capture_open_files > "$ctx_dir/open_files.txt"
    
    # 4. VS Code State (mocked/simple)
    capture_vscode_state > "$ctx_dir/vscode_state.txt"
    
    echo "Context '$name' captured successfully."
}

# Restore a context (print instructions or perform cd)
# Usage: restore_context <name>
restore_context() {
    local name="$1"
    _context_validate_name "$name" || return 1

    local ctx_dir="$CONTEXT_ROOT/$name"

    if [ ! -d "$ctx_dir" ]; then
        echo "Error: Context '$name' not found." >&2
        return 1
    fi

    if [ ! -f "$ctx_dir/directory.txt" ]; then
        echo "Error: Context '$name' is missing directory metadata." >&2
        return 1
    fi

    local dir
    dir=$(head -n 1 "$ctx_dir/directory.txt")
    if [[ -z "$dir" || "$dir" != /* ]]; then
        echo "Error: Context '$name' has an invalid directory path." >&2
        return 1
    fi

    printf '%s\n' "$dir"
}

# Restore and change directory in the current shell.
# Usage: restore_context_dir <name>
restore_context_dir() {
    local name="$1"
    local dir

    dir=$(restore_context "$name") || return 1
    cd "$dir" || return 1
    return 0
}

# List all saved contexts
# Usage: list_contexts
list_contexts() {
    if [ ! -d "$CONTEXT_ROOT" ] || [ -z "$(ls -A "$CONTEXT_ROOT")" ]; then
        echo "No saved contexts."
        return
    fi
    
    for d in "$CONTEXT_ROOT"/*; do
        if [ -d "$d" ]; then
            local name=$(basename "$d")
            local ts=$(cat "$d/timestamp.txt" 2>/dev/null)
            local dir=$(cat "$d/directory.txt" 2>/dev/null)
            printf "%-20s | %-20s | %s\n" "$name" "$ts" "$dir"
        fi
    done
}

# Diff two contexts
# Usage: diff_contexts <name1> <name2>
diff_contexts() {
    local name1="$1"
    local name2="$2"
    diff -r "$CONTEXT_ROOT/$name1" "$CONTEXT_ROOT/$name2"
}

# Setup to capture git state
capture_git_state() {
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "BRANCH: $(git rev-parse --abbrev-ref HEAD)"
        echo "STATUS:"
        git status --short
    else
        echo "Not a git repository"
    fi
}

# Capture open files (simplified for macOS/lsof)
capture_open_files() {
    # This is tricky without being intrusive. 
    # Just checking for common editors
    pgrep -l "Code|vim|nano" || echo "No common editors found running"
}

# Capture VS Code state
capture_vscode_state() {
    # Placeholder
    # Placeholder for future VS Code integration
    echo "VS Code state capture not implemented"
}
