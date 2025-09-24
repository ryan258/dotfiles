#!/bin/bash
# goto.sh - Directory bookmarking system for macOS

BOOKMARKS_FILE=~/.dir_bookmarks

is_sourced() {
    if [ -n "$ZSH_VERSION" ]; then
        case $ZSH_EVAL_CONTEXT in
            *:file) return 0 ;;
        esac
        return 1
    elif [ -n "$BASH_VERSION" ]; then
        [[ ${BASH_SOURCE[0]} != "$0" ]]
        return
    fi
    return 1
}

case "$1" in
    save)
        if [ -z "$2" ]; then
            echo "Usage: goto save <bookmark_name>"
            exit 1
        fi
        echo "$2:$(pwd)" >> "$BOOKMARKS_FILE"
        echo "Saved '$(pwd)' as bookmark '$2'"
        ;;
    
    list)
        echo "=== Directory Bookmarks ==="
        if [ -f "$BOOKMARKS_FILE" ]; then
            cat "$BOOKMARKS_FILE" | sed 's/:/ -> /'
        else
            echo "No bookmarks saved yet."
        fi
        ;;
    
    *)
        if [ -z "$1" ]; then
            echo "Usage:"
            echo "  goto save <name>  : Save current directory"
            echo "  goto list         : List all bookmarks"
            echo "  goto <name>       : Jump to bookmark"
            exit 1
        fi
        
        if [ -f "$BOOKMARKS_FILE" ]; then
            TARGET=$(awk -F':' -v key="$1" '$1==key { $1=""; sub(/^:/, ""); print; exit }' "$BOOKMARKS_FILE")
            if [ -n "$TARGET" ]; then
                if is_sourced; then
                    if ! builtin cd "$TARGET"; then
                        echo "Failed to change directory to: $TARGET"
                        return 1
                    fi
                    echo "Jumped to: $TARGET"
                else
                    echo "$TARGET"
                    printf "Tip: run 'cd \"%s\"' or source the script for direct jumps.\n" "$TARGET" >&2
                fi
            else
                echo "Bookmark '$1' not found. Use 'goto list' to see available bookmarks."
            fi
        else
            echo "No bookmarks file found."
        fi
        ;;
esac

# ---
