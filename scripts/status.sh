#!/usr/bin/env bash
set -euo pipefail
# status.sh - Provides a mid-day context recovery dashboard.

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/config.sh"
fi

DATA_DIR="${DATA_DIR:-$HOME/.config/dotfiles-data}"
STATE_DIR="${STATE_DIR:-$DATA_DIR}"
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

# --- Context Snapshots ---
CONTEXT_ROOT="${CONTEXT_ROOT:-$DATA_DIR/contexts}"
if [ -d "$CONTEXT_ROOT" ]; then
    CONTEXT_COUNT=$(find "$CONTEXT_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    if [ "$CONTEXT_COUNT" -gt 0 ]; then
        echo "  • Context snapshots: $CONTEXT_COUNT (context.sh list)"
    fi
fi

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
    TODAY_ENTRIES=$(awk -F'|' -v today="$TODAY" '$1 ~ "^"today {print "  "$0}' "$JOURNAL_FILE")
    if [ -n "$TODAY_ENTRIES" ]; then
        echo "$TODAY_ENTRIES"
    else
        echo "  (No entries for today yet)"
    fi
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
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
HEALTH_SCRIPT="${HEALTH_SCRIPT:-$DOTFILES_DIR/scripts/health.sh}"
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
