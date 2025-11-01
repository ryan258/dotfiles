#!/bin/bash
set -euo pipefail
# status.sh - Provides a mid-day context recovery dashboard.

# --- Configuration ---
JOURNAL_FILE="$HOME/.config/dotfiles-data/journal.txt"
TODO_FILE="$HOME/.config/dotfiles-data/todo.txt"
PROJECTS_DIR=~/Projects

# --- Display Header ---
echo "🧭 WHERE YOU ARE:"
CURRENT_DIR=$(pwd)
echo "  • Current directory: $CURRENT_DIR"

# --- Git Information ---
if [ -d ".git" ] || git rev-parse --git-dir > /dev/null 2>&1; then
    GIT_BRANCH=$(git branch --show-current)
    echo "  • Current git branch: $GIT_BRANCH"
fi

# --- Last Journal Entry ---
if [ -f "$JOURNAL_FILE" ]; then
    LAST_ENTRY=$(tail -n 1 "$JOURNAL_FILE")
    echo "  • Last journal entry: $LAST_ENTRY"
fi

# --- Today's Journal ---
echo ""
echo "📝 TODAY'S JOURNAL (since midnight):"
if [ -f "$JOURNAL_FILE" ]; then
    TODAY=$(date +%Y-%m-%d)
    grep "\[$TODAY" "$JOURNAL_FILE" | sed 's/^/  /' || echo "  (No entries for today yet)"
fi

# --- Active Project ---
echo ""
echo "🚀 ACTIVE PROJECT:"
if [[ "$CURRENT_DIR" == "$PROJECTS_DIR"* ]]; then
    PROJECT_NAME=$(basename "$CURRENT_DIR")
    echo "  • Project: $PROJECT_NAME"
    if [ -d ".git" ] || git rev-parse --git-dir > /dev/null 2>&1; then
        LAST_COMMIT=$(git log -1 --format="%ar: %s")
        echo "  • Last commit: $LAST_COMMIT"
    fi
else
    echo "  (Not in a project directory under $PROJECTS_DIR)"
fi

# --- Tasks ---
echo ""
echo "✅ TASKS:"
if [ -f "$TODO_FILE" ] && [ -s "$TODO_FILE" ]; then
    cat -n "$TODO_FILE" | sed 's/^/  /'
else
    echo "  (No tasks yet)"
fi

# --- Footer ---
echo ""
echo "💡 Commands: journal | todo | startday | goodevening"
