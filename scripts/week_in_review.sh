#!/bin/bash
# week_in_review.sh - Generates a report of your activity over the last week

echo "========================================"
echo "    Your Week in Review: $(date +%F)"
echo "========================================"

# --- Completed Tasks ---
if [ -f ~/.todo_done.txt ]; then
    echo -e "\n## Recently Completed Tasks ##"
    # This looks for tasks completed in the last 7 days
    awk -v cutoff="$(date -v-7d +%F)" '
        match($0, /\[([0-9]{4}-[0-9]{2}-[0-9]{2})/, m) {
            if (m[1] >= cutoff) {
                print
            }
        }
    ' ~/.todo_done.txt
fi

# --- Journal Entries ---
if [ -f ~/journal.txt ]; then
    echo -e "\n## Recent Journal Entries ##"
    awk -v cutoff="$(date -v-7d +%F)" '
        match($0, /\[([0-9]{4}-[0-9]{2}-[0-9]{2})/, m) {
            if (m[1] >= cutoff) {
                print
            }
        }
    ' ~/journal.txt
fi

# --- Git Contributions (in current project) ---
if [ -d .git ]; then
    MY_NAME=$(git config user.name)
    echo -e "\n## Git Contributions This Week ##"
    git log --oneline --author="$MY_NAME" --since="1 week ago"
fi

echo -e "\n========================================"

# ---
