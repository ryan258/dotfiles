#!/usr/bin/env bash
set -euo pipefail

# context.sh - Capture and restore working context snapshots

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_LIB="$SCRIPT_DIR/lib/config.sh"

if [ -f "$CONFIG_LIB" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_LIB"
else
    echo "Error: configuration library not found at $CONFIG_LIB" >&2
    exit 1
fi

if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/common.sh"
fi

if [ -f "$SCRIPT_DIR/lib/context_capture.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/context_capture.sh"
else
    echo "Error: context_capture library not found." >&2
    exit 1
fi

usage() {
    cat << 'EOF'
Usage: context.sh {capture|list|show|path|restore} [name]

Commands:
  capture [name]   Capture current context snapshot (optional name)
  list             List saved contexts
  show <name>      Show summary (timestamp + directory) for a context
  path <name>      Print the directory for a context
  restore <name>   Show restore details (directory + git preview)
EOF
}

sanitize_name() {
    local value="$1"
    value=$(sanitize_input "$value")
    value=${value//$'\n'/ }
    printf '%s' "$value"
}

case "${1:-}" in
    capture)
        shift || true
        name="${1:-}"
        if [ -n "$name" ]; then
            name=$(sanitize_name "$name")
            capture_current_context "$name"
        else
            capture_current_context
        fi
        ;;
    list)
        list_contexts
        ;;
    show)
        if [ -z "${2:-}" ]; then
            echo "Error: Context name required." >&2
            exit 1
        fi
        name=$(sanitize_name "$2")
        ctx_dir="$CONTEXT_ROOT/$name"
        if [ ! -d "$ctx_dir" ]; then
            echo "Error: Context '$name' not found." >&2
            exit 1
        fi
        echo "Context: $name"
        if [ -f "$ctx_dir/timestamp.txt" ]; then
            echo "  Captured: $(cat "$ctx_dir/timestamp.txt")"
        fi
        if [ -f "$ctx_dir/directory.txt" ]; then
            echo "  Directory: $(cat "$ctx_dir/directory.txt")"
        fi
        ;;
    path)
        if [ -z "${2:-}" ]; then
            echo "Error: Context name required." >&2
            exit 1
        fi
        name=$(sanitize_name "$2")
        ctx_dir="$CONTEXT_ROOT/$name"
        if [ ! -d "$ctx_dir" ]; then
            echo "Error: Context '$name' not found." >&2
            exit 1
        fi
        if [ -f "$ctx_dir/directory.txt" ]; then
            cat "$ctx_dir/directory.txt"
        else
            echo "Error: Missing directory.txt for context '$name'." >&2
            exit 1
        fi
        ;;
    restore)
        if [ -z "${2:-}" ]; then
            echo "Error: Context name required." >&2
            exit 1
        fi
        name=$(sanitize_name "$2")
        restore_dir=$(restore_context "$name")
        echo "Directory: $restore_dir"
        ctx_dir="$CONTEXT_ROOT/$name"
        if [ -f "$ctx_dir/git_state.txt" ]; then
            echo "# Git state at capture:"
            head -n 3 "$ctx_dir/git_state.txt"
        fi
        echo ""
        echo "Tip: run 'cd \"\$(context.sh path $name)\"' to jump into that directory."
        ;;
    -h|--help|help|"")
        usage
        ;;
    *)
        echo "Error: Unknown command '$1'." >&2
        usage
        exit 1
        ;;
esac
