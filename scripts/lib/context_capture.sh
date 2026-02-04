#!/usr/bin/env bash
# scripts/lib/context_capture.sh
# Shared library for context preservation
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_CONTEXT_CAPTURE_LOADED:-}" ]]; then
    return 0
fi
readonly _CONTEXT_CAPTURE_LOADED=true

CONTEXT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$CONTEXT_DIR/config.sh" ]]; then
    source "$CONTEXT_DIR/config.sh"
fi

DATA_DIR="${DATA_DIR:-$HOME/.config/dotfiles-data}"
CONTEXT_ROOT="$DATA_DIR/contexts"

mkdir -p "$CONTEXT_ROOT"

# Capture the current working context
# Usage: capture_current_context [name]
capture_current_context() {
    local name="${1:-auto-$(date +%Y%m%d-%H%M)}"
    
    # Validate name contains no path separators
    if [[ "$name" == *"/"* ]] || [[ "$name" == *".."* ]]; then
        echo "Error: Invalid context name" >&2
        return 1
    fi

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
    local ctx_dir="$CONTEXT_ROOT/$name"
    
    if [ ! -d "$ctx_dir" ]; then
        echo "Error: Context '$name' not found." >&2
        return 1
    fi
    
    local dir=$(cat "$ctx_dir/directory.txt")
    echo "cd \"${dir}\"" # Intended for eval or user info
    
    if [ -f "$ctx_dir/git_state.txt" ]; then
        echo "# Git state at capture:"
        head -n 3 "$ctx_dir/git_state.txt"
    fi
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
    # TODO: Implement VS Code state capture via CLI or API
    echo "VS Code state capture not implemented"
}
