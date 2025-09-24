#!/bin/bash
# startday.sh - Morning startup routine

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

echo "Good morning! It is currently $(date)"
echo "----------------------------------------"

# Navigate to a primary work folder (customize this path)
TARGET_DIR=""
if [ -d "$HOME/projects" ]; then
    TARGET_DIR="$HOME/projects"
    echo "Suggested workspace: $TARGET_DIR"
elif [ -d "$HOME/Documents" ]; then
    TARGET_DIR="$HOME/Documents"
    echo "Suggested workspace: $TARGET_DIR"
fi

if [ -n "$TARGET_DIR" ]; then
    if is_sourced; then
        if ! builtin cd "$TARGET_DIR"; then
            echo "Failed to change directory to $TARGET_DIR"
            return 1
        fi
        echo "You are in your workspace directory."
    else
        printf "Tip: run 'cd \"%s\"' or source startday.sh to jump automatically.\n" "$TARGET_DIR" >&2
    fi
fi

# Display the contents of a simple to-do list file
if [ -f ~/.todo_list.txt ]; then
    echo ""
    echo "Your TODOs for today:"
    cat ~/.todo_list.txt
fi

echo ""
echo "Have a productive day!"
