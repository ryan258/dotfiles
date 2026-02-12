#!/usr/bin/env bash
set -euo pipefail
# status.sh - Provides a mid-day context recovery dashboard.

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/common.sh"
else
    echo "Error: common utilities not found at $SCRIPT_DIR/lib/common.sh" >&2
    exit 1
fi
if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/config.sh"
else
    die "configuration library not found at $SCRIPT_DIR/lib/config.sh" "$EXIT_FILE_NOT_FOUND"
fi
if [ -f "$SCRIPT_DIR/lib/date_utils.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/date_utils.sh"
else
    die "date utilities not found at $SCRIPT_DIR/lib/date_utils.sh" "$EXIT_FILE_NOT_FOUND"
fi

FOCUS_FILE="${FOCUS_FILE:?FOCUS_FILE is not set by config.sh}"
JOURNAL_FILE="${JOURNAL_FILE:?JOURNAL_FILE is not set by config.sh}"
TODO_FILE="${TODO_FILE:?TODO_FILE is not set by config.sh}"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/Projects}"

# Source new libraries
if [ -f "$SCRIPT_DIR/lib/health_ops.sh" ]; then
    source "$SCRIPT_DIR/lib/health_ops.sh"
fi
if [ -f "$SCRIPT_DIR/lib/github_ops.sh" ]; then
    source "$SCRIPT_DIR/lib/github_ops.sh"
fi

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
    TODAY=$(date_today)
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

# --- Today's Commits ---
echo ""
echo "🧾 TODAY'S COMMITS:"
if command -v get_commit_activity_for_date >/dev/null 2>&1; then
    TODAY=$(date_today)
    if TODAY_COMMITS=$(get_commit_activity_for_date "$TODAY" 2>/dev/null); then
        if [ -n "$TODAY_COMMITS" ]; then
            echo "$TODAY_COMMITS"
        else
            echo "  (No commits yet today)"
        fi
    else
        echo "  (Unable to fetch commit activity)"
    fi
else
    echo "  (GitHub operations library not loaded)"
fi

# --- Health Check (interactive only) ---
HEALTH_SCRIPT="${HEALTH_SCRIPT:-$DOTFILES_DIR/scripts/health.sh}"

# Show Health Summary
echo ""
echo "🏥 HEALTH STATUS:"
if command -v show_health_summary >/dev/null 2>&1; then
    show_health_summary
fi

if [ -t 0 ] && [ -x "$HEALTH_SCRIPT" ]; then
    echo ""
    echo -n "🏥 Log Energy/Fog levels? [y/N]: "
    read -r log_health
    if [[ "$log_health" =~ ^[yY] ]]; then
        echo -n "   Energy Level (1-10): "
        read -r energy
        if validate_range "$energy" 1 10 "energy level" >/dev/null 2>&1; then
            "$HEALTH_SCRIPT" energy "$energy" | sed 's/^/   /'
        elif [ -n "$energy" ]; then
            echo "   (Skipped: must be 1-10)"
        fi

        echo -n "   Brain Fog Level (1-10): "
        read -r fog
        if validate_range "$fog" 1 10 "brain fog level" >/dev/null 2>&1; then
            "$HEALTH_SCRIPT" fog "$fog" | sed 's/^/   /'
        elif [ -n "$fog" ]; then
            echo "   (Skipped: must be 1-10)"
        fi
    fi
fi

# --- Tasks ---
echo ""
echo "✅ TASKS:"
if [ -x "$SCRIPT_DIR/todo.sh" ]; then
    "$SCRIPT_DIR/todo.sh" top 3
else
    echo "  (todo.sh not found)"
fi

# --- Footer ---
echo ""
echo "💡 Commands: journal | todo | startday | goodevening"
