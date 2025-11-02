#!/bin/bash
# recent_dirs.sh - Navigate to recently visited directories (macOS)

HISTORY_FILE="$HOME/.config/dotfiles-data/dir_history"
MAX_HISTORY=20

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

# Function to add current directory to history
add_to_history() {
    pwd >> "$HISTORY_FILE"
    # Keep only last MAX_HISTORY entries
    if [ -f "$HISTORY_FILE" ]; then
        tail -n "$MAX_HISTORY" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp"
        mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
    fi
}

# Add current directory to history if called with 'add'
if [ "$1" = "add" ]; then
    add_to_history
    exit 0
fi

# Show recent directories with numbers
if [ ! -f "$HISTORY_FILE" ]; then
    echo "No directory history found."
    echo "Start building history by adding this alias to your ~/.zshrc:"
    echo "alias cd='function cd_with_history(){ builtin cd \"\$@\" && ~/scripts/recent_dirs.sh add; }; cd_with_history'"
    exit 1
fi

echo "=== Recent Directories ==="
# Use tail and reverse to show most recent first, with line numbers
tail -r "$HISTORY_FILE" | head -n 10 | nl

echo ""
IFS= read -r -p "Enter number to jump to (or Enter to cancel): " choice

if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le 10 ]; then
    TARGET=$(tail -r "$HISTORY_FILE" | head -n 10 | sed -n "${choice}p")
    if [ -d "$TARGET" ]; then
        if is_sourced; then
            if ! builtin cd "$TARGET"; then
                echo "Failed to change directory to: $TARGET"
                return 1
            fi
            echo "Jumped to: $TARGET"
        else
            printf "Selected: %s\n" "$TARGET"
            printf "Tip: source the script (e.g. 'source ~/scripts/recent_dirs.sh') to jump automatically.\n" >&2
        fi
    else
        echo "Directory no longer exists: $TARGET"
    fi
fi
