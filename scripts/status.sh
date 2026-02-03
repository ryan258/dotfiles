#!/bin/bash
set -euo pipefail
# status.sh - Provides a mid-day context recovery dashboard.

# --- Configuration ---
STATE_DIR="${STATE_DIR:-$HOME/.config/dotfiles-data}"
FOCUS_FILE="${FOCUS_FILE:-$STATE_DIR/daily_focus.txt}"
JOURNAL_FILE="${JOURNAL_FILE:-$STATE_DIR/journal.txt}"
TODO_FILE="${TODO_FILE:-$STATE_DIR/todo.txt}"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/Projects}"

# --- Focus ---
echo ""
echo "🎯 TODAY'S FOCUS:"
if [ -f "$FOCUS_FILE" ] && [ -s "$FOCUS_FILE" ]; then
    echo "  $(cat "$FOCUS_FILE")"
else
    echo "  (No focus set)"
fi

# --- Display Header ---
echo ""
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

# --- Health Check (interactive only) ---
HEALTH_SCRIPT="${HEALTH_SCRIPT:-$HOME/dotfiles/scripts/health.sh}"
if [ -t 0 ] && [ -x "$HEALTH_SCRIPT" ]; then
    echo ""
    echo -n "🏥 Log Energy/Fog levels? [y/N]: "
    read -r log_health
    if [[ "$log_health" =~ ^[yY] ]]; then
        echo -n "   Energy Level (1-10): "
        read -r energy
        if [[ "$energy" =~ ^[0-9]+$ ]] && [ "$energy" -ge 1 ] && [ "$energy" -le 10 ]; then
            "$HEALTH_SCRIPT" energy "$energy" | sed 's/^/   /'
        elif [ -n "$energy" ]; then
            echo "   (Skipped: must be 1-10)"
        fi

        echo -n "   Brain Fog Level (1-10): "
        read -r fog
        if [[ "$fog" =~ ^[0-9]+$ ]] && [ "$fog" -ge 1 ] && [ "$fog" -le 10 ]; then
            "$HEALTH_SCRIPT" fog "$fog" | sed 's/^/   /'
        elif [ -n "$fog" ]; then
            echo "   (Skipped: must be 1-10)"
        fi
    fi
fi

# --- Tasks ---
echo ""
echo "✅ TASKS:"
if [ -f "$HOME/dotfiles/scripts/todo.sh" ]; then
    "$HOME/dotfiles/scripts/todo.sh" top 3
else
    echo "  (todo.sh not found)"
fi

# --- Footer ---
echo ""
echo "💡 Commands: journal | todo | startday | goodevening"
