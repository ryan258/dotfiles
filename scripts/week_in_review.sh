#!/bin/bash
set -euo pipefail
# week_in_review.sh - Generates a report of your activity over the last week

echo "========================================"
echo "    Your Week in Review: $(date +%F)"
echo "========================================"

# --- Completed Tasks ---
TODO_DONE_FILE="$HOME/.config/dotfiles-data/todo_done.txt"
if [ -f "$TODO_DONE_FILE" ]; then
    echo -e "\n## Recently Completed Tasks ##"
    # This looks for tasks completed in the last 7 days
    awk -v cutoff="$(date -v-7d +%F)" '
        match($0, /\[([0-9]{4}-[0-9]{2}-[0-9]{2})/, m) {
            if (m[1] >= cutoff) {
                print
            }
        }
    ' "$TODO_DONE_FILE"
fi

# --- Journal Entries ---
JOURNAL_FILE="$HOME/.config/dotfiles-data/journal.txt"
if [ -f "$JOURNAL_FILE" ]; then
    echo -e "\n## Recent Journal Entries ##"
    awk -v cutoff="$(date -v-7d +%F)" '
        match($0, /\[([0-9]{4}-[0-9]{2}-[0-9]{2})/, m) {
            if (m[1] >= cutoff) {
                print
            }
        }
    ' "$JOURNAL_FILE"
fi

# --- Git Contributions (in current project) ---
if [ -d .git ]; then
    MY_NAME=$(git config user.name)
    echo -e "\n## Git Contributions This Week ##"
    git log --oneline --author="$MY_NAME" --since="1 week ago"
fi

echo -e "\n========================================"

# ---
