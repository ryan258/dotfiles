#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
TODO_DONE_FILE="$HOME/.config/dotfiles-data/todo_done.txt"
JOURNAL_FILE="$HOME/.config/dotfiles-data/journal.txt"
PROJECTS_DIR=~/Projects

echo "=== Evening Close-Out — $(date '+%Y-%m-%d %H:%M') ==="

# 1. Show completed tasks from today
echo ""
echo "✅ COMPLETED TODAY:"
if [ -f "$TODO_DONE_FILE" ]; then
    TODAY=$(date +%Y-%m-%d)
    grep "\[$TODAY" "$TODO_DONE_FILE" | sed 's/^/  • /' || echo "  (No tasks completed today)"
fi

# 2. Show today's journal entries
echo ""
echo "📝 TODAY'S JOURNAL:"
if [ -f "$JOURNAL_FILE" ]; then
    TODAY=$(date +%Y-%m-%d)
    grep "\[$TODAY" "$JOURNAL_FILE" | sed 's/^/  • /' || echo "  (No journal entries for today)"
fi

# 3. List active projects with uncommitted changes
echo ""
echo "🚀 ACTIVE PROJECTS (with uncommitted changes):"
if [ -d "$PROJECTS_DIR" ]; then
    found_changes=false
    while IFS= read -r gitdir; do
        proj_dir=$(dirname "$gitdir")
        if (cd "$proj_dir" && git status --porcelain | grep -q .); then
            echo "  • $(basename "$proj_dir") has uncommitted changes."
            found_changes=true
        fi
    done < <(find "$PROJECTS_DIR" -maxdepth 2 -type d -name ".git")

    if [ "$found_changes" = false ]; then
        echo "  (All projects are committed)"
    fi
else
    echo "  (Projects directory not found)"
fi

# 4. Prompt for tomorrow's note
echo ""
IFS= read -r -p "What should tomorrow-you remember about today? (Press Enter to skip) " note
if [ -n "$note" ]; then
    # 5. Add response to journal
    # Assuming journal.sh is in the same directory or in PATH
    "$(dirname "$0")/journal.sh" "EOD Note: $note"
fi

# 6. Clear completed tasks older than 7 days
echo ""
echo "🧹 Tidying up old completed tasks..."
if [ -f "$TODO_DONE_FILE" ]; then
    CUTOFF_DATE_STR=$(date -v-7d '+%Y-%m-%d')
    awk -v cutoff="$CUTOFF_DATE_STR" '
        $0 ~ /^\[/ {
            date_str = substr($1, 2, 10)
            if (date_str >= cutoff) {
                print
            }
        }
        $0 !~ /^\[/ { print } # print lines without date
    ' "$TODO_DONE_FILE" > "${TODO_DONE_FILE}.tmp" && mv "${TODO_DONE_FILE}.tmp" "$TODO_DONE_FILE"
    echo "  (Old completed tasks removed)"
fi

echo ""
echo "Evening wrap-up complete. Have a great night!"
