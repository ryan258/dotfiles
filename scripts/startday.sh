#!/usr/bin/env bash
set -euo pipefail
# startday.sh - Enhanced morning routine

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE_UTILS="$SCRIPT_DIR/lib/date_utils.sh"
if [ -f "$DATE_UTILS" ]; then
    # shellcheck disable=SC1090
    source "$DATE_UTILS"
else
    echo "Error: date utilities not found at $DATE_UTILS" >&2
    exit 1
fi

# --- CONFIGURATION ---
if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/config.sh"
else
    # Fallback
    DATA_DIR="${DATA_DIR:-$HOME/.config/dotfiles-data}"
    CURRENT_DAY_FILE="$DATA_DIR/current_day"
    # Ensure exports for compatibility if config missing
    export FOCUS_FILE="$DATA_DIR/daily_focus.txt"
fi

# Source new libraries
if [ -f "$SCRIPT_DIR/lib/github_ops.sh" ]; then
    source "$SCRIPT_DIR/lib/github_ops.sh"
fi
if [ -f "$SCRIPT_DIR/lib/health_ops.sh" ]; then
    source "$SCRIPT_DIR/lib/health_ops.sh"
fi

DATA_DIR="${DATA_DIR:-$HOME/.config/dotfiles-data}"
mkdir -p "$DATA_DIR"
CURRENT_DAY_FILE="${CURRENT_DAY_FILE:-$DATA_DIR/current_day}"
FOCUS_FILE="${FOCUS_FILE:-$DATA_DIR/daily_focus.txt}"
BRIEFING_CACHE="${BRIEFING_CACHE_FILE:-$DATA_DIR/.ai_briefing_cache}"

# Support "refresh" to force new AI briefing
if [[ "${1:-}" == "refresh" ]]; then
    rm -f "$BRIEFING_CACHE"
    echo "🔄 Cache cleared. Forcing new session data..."
fi

# Persist the start date of this session
date +%Y-%m-%d > "$CURRENT_DAY_FILE"

CONTEXT_CAPTURE_ON_START="${CONTEXT_CAPTURE_ON_START:-false}"
if [ "$CONTEXT_CAPTURE_ON_START" = "true" ]; then
    CONTEXT_SCRIPT="$SCRIPT_DIR/context.sh"
    if [ -x "$CONTEXT_SCRIPT" ]; then
        "$CONTEXT_SCRIPT" capture "startday-$(date +%Y%m%d-%H%M)" >/dev/null 2>&1 || true
    fi
fi

SPOON_MANAGER="$SCRIPT_DIR/spoon_manager.sh"

# 1. Daily Focus
FOCUS_SCRIPT="$SCRIPT_DIR/focus.sh"
if [ -t 0 ]; then
    # Interactive mode
    if [ -f "$FOCUS_FILE" ] && [ -s "$FOCUS_FILE" ]; then
        CURRENT_FOCUS=$(cat "$FOCUS_FILE")
        echo "🎯 TODAY'S FOCUS: $CURRENT_FOCUS"
        echo -n "   Update focus? [y/N]: "
        read -r update_focus
        if [[ "$update_focus" =~ ^[yY] ]]; then
            echo -n "   Enter new focus: "
            read -r new_focus
            if [ -n "$new_focus" ] && [ -x "$FOCUS_SCRIPT" ]; then
                "$FOCUS_SCRIPT" set "$new_focus"
            fi
        fi
    else
        echo "🎯 NO FOCUS SET."
        echo -n "   What is your main focus for today? (Enter to skip): "
        read -r new_focus
        if [ -n "$new_focus" ] && [ -x "$FOCUS_SCRIPT" ]; then
            "$FOCUS_SCRIPT" set "$new_focus" >/dev/null
            echo "   Focus set to: $new_focus"
        fi
    fi
    echo ""
else
    # Non-interactive mode: just display if present
    if [ -f "$FOCUS_FILE" ] && [ -s "$FOCUS_FILE" ]; then
        echo "🎯 TODAY'S FOCUS: $(cat "$FOCUS_FILE")"
        echo ""
    fi
fi

# 2. Initialize Daily Spoons (Energy Budget)
echo "🥣 SPOON CHECK:"
if [ -x "$SPOON_MANAGER" ]; then
    # Check if already initialized
    if "$SPOON_MANAGER" check &>/dev/null; then
        remaining=$("$SPOON_MANAGER" check | grep -oE -- '-?[0-9]+' || echo "?")
        echo "  You have $remaining spoons remaining today."
        if [ -t 0 ]; then
            echo -n "  Update spoon budget? [y/N]: "
            read -r update_spoons
            if [[ "$update_spoons" =~ ^[yY] ]]; then
                echo -n "  How many spoons do you have today? [10]: "
                read -r spoons_input
                spoons_count="${spoons_input:-10}"
                if ! [[ "$spoons_count" =~ ^[0-9]+$ ]]; then
                    echo "  Invalid input, defaulting to 10."
                    spoons_count=10
                fi
                "$SPOON_MANAGER" set "$spoons_count" | sed 's/^/  /'
            fi
        fi
    else
        # Not initialized yet - prompt for spoons
        if [ -t 0 ]; then
            echo -n "  How many spoons do you have today? [10]: "
            read -r spoons_input
            spoons_count="${spoons_input:-10}"
        else
            echo "  (Non-interactive mode: defaulting to 10)"
            spoons_count=10
        fi

        if ! [[ "$spoons_count" =~ ^[0-9]+$ ]]; then
            echo "  Invalid input, defaulting to 10."
            spoons_count=10
        fi

        "$SPOON_MANAGER" init "$spoons_count" | sed 's/^/  /'
    fi
else
    echo "  (Spoon manager not found)"
fi

# --- LOGGING ---
SYSTEM_LOG_FILE="${SYSTEM_LOG:-$DATA_DIR/system.log}"
echo "$(date): startday.sh - Running morning routine." >> "$SYSTEM_LOG_FILE"

# Load environment variables for optional AI features
if [ -f "$SCRIPT_DIR/../.env" ]; then
    source "$SCRIPT_DIR/../.env"
fi

BLOG_SCRIPT="$SCRIPT_DIR/blog.sh"
BLOG_STATUS_DIR="${BLOG_STATUS_DIR:-${BLOG_DIR:-}}"
BLOG_CONTENT_ROOT="${BLOG_CONTENT_DIR:-}"
if [ -z "$BLOG_CONTENT_ROOT" ] && [ -n "$BLOG_STATUS_DIR" ]; then
    BLOG_CONTENT_ROOT="$BLOG_STATUS_DIR/content"
fi
BLOG_READY=false
if [ -f "$BLOG_SCRIPT" ] && [ -n "$BLOG_STATUS_DIR" ] && [ -d "$BLOG_STATUS_DIR" ]; then
    BLOG_READY=true
fi

# --- YESTERDAY'S CONTEXT ---
JOURNAL_FILE="${JOURNAL_FILE:-$DATA_DIR/journal.txt}"
echo ""
echo "📅 YESTERDAY YOU WERE:"
if [ -f "$JOURNAL_FILE" ]; then
    echo "Journal entries:"
    yesterday=$(date_shift_days -1 "%Y-%m-%d")
    yesterday_entries=$(awk -F'|' -v day="$yesterday" '$1 ~ "^"day {print "  • " $0}' "$JOURNAL_FILE")
    if [ -n "$yesterday_entries" ]; then
        echo "$yesterday_entries"
    else
        echo "  (No entries for $yesterday)"
    fi
else
    echo "  (Journal file not found)"
fi

# --- WEEKLY REVIEW ---
if [ "$(date +%u)" -eq 1 ]; then
    WEEK_NUM=$(date_shift_days -1 "%V")
    YEAR=$(date_shift_days -1 "%Y")
    REVIEW_FILE="$HOME/Documents/Reviews/Weekly/$YEAR-W$WEEK_NUM.md"
    if [ -f "$REVIEW_FILE" ]; then
        echo ""
        echo "📈 LAST WEEK'S REVIEW:"
        echo "  • Last week's review is available at: $REVIEW_FILE"
    fi
fi


# --- ACTIVE PROJECTS (from GitHub) ---
echo ""
echo "🚀 ACTIVE PROJECTS (pushed to GitHub in last 7 days):"
if command -v get_recent_github_activity >/dev/null 2>&1; then
    if RECENT_PUSHES=$(get_recent_github_activity 7); then
        if [ -n "$RECENT_PUSHES" ]; then
            echo "$RECENT_PUSHES"
        else
            echo "  (No recent pushes)"
        fi
    else
        echo "  (Unable to fetch GitHub activity. Check your token or network.)"
        RECENT_PUSHES="(none)"
    fi
else
    echo "  (GitHub operations library not loaded)"
    RECENT_PUSHES="(none)"
fi

# --- YESTERDAY'S COMMITS ---
echo ""
echo "🧾 YESTERDAY'S COMMITS:"
if command -v get_commit_activity_for_date >/dev/null 2>&1; then
    yesterday_commits=$(date_shift_days -1 "%Y-%m-%d")
    if ! get_commit_activity_for_date "$yesterday_commits"; then
        echo "  (Unable to fetch commit activity. Check your token or network.)"
    fi
else
    echo "  (GitHub operations library not loaded)"
fi

# --- SUGGESTED DIRECTORIES ---
echo ""
echo "💡 SUGGESTED DIRECTORIES:"
if [ -f "$SCRIPT_DIR/g.sh" ]; then
    "$SCRIPT_DIR/g.sh" suggest | head -n 3 | awk '{print "  • " $2}'
fi

# --- BLOG STATUS ---
if [ "$BLOG_READY" = true ]; then
    echo ""
    if ! BLOG_DIR="$BLOG_STATUS_DIR" "$BLOG_SCRIPT" status; then
        echo "  ⚠️ Blog status unavailable (check BLOG_STATUS_DIR or BLOG_DIR configuration)."
    fi
    if [ -f "$SCRIPT_DIR/blog_recent_content.sh" ]; then
        echo ""
        echo "📰 LATEST BLOG CONTENT:"
        if ! BLOG_CONTENT_DIR="$BLOG_CONTENT_ROOT" "$SCRIPT_DIR/blog_recent_content.sh" 3; then
            echo "  ⚠️ Unable to list recent content (check BLOG_CONTENT_DIR)."
        fi
    fi
fi

# --- Helpers ---
# --- HEALTH ---
echo ""
echo "🏥 HEALTH:"
if command -v show_health_summary >/dev/null 2>&1; then
    show_health_summary
else
    echo "  (Health operations library not loaded)"
fi

# --- SCHEDULED TASKS ---
echo ""
echo "🗓️  TODAY'S SCHEDULE:"
CALENDAR_SCRIPT="$SCRIPT_DIR/gcal.sh"
if [ -x "$CALENDAR_SCRIPT" ]; then
    # Show agenda. If auth fails, gcal.sh will exit non-zero.
    # We capture output. If it fails due to creds, we show a hint.
    if OUTPUT=$("$CALENDAR_SCRIPT" agenda 1 2>&1); then
        echo "$OUTPUT" | sed 's/^/  /'
    else
        echo "  (Authentication required. Run 'gcal auth')"
    fi
else
    echo "  (calendar script not found)"
fi
echo ""
echo "⏳ SCHEDULED JOBS (atq):"
if command -v atq >/dev/null 2>&1; then
    atq | sed 's/^/  /' || echo "  (No background jobs)"
else
    echo "  (at command not available)"
fi

# --- STALE TASKS (older than 7 days) ---
STALE_TODO_FILE="${TODO_FILE:-$DATA_DIR/todo.txt}"
echo ""
echo "⏰ STALE TASKS:"
if [ -f "$STALE_TODO_FILE" ] && [ -s "$STALE_TODO_FILE" ]; then
    CUTOFF_DATE=$(date_shift_days "-${STALE_TASK_DAYS:-7}" "%Y-%m-%d")
    awk -F'|' -v cutoff="$CUTOFF_DATE" '$1 < cutoff { printf "  • %s (from %s)\n", $2, $1 }' "$STALE_TODO_FILE"
fi

# --- TODAY'S TASKS ---
TODO_FILE="${TODO_FILE:-$DATA_DIR/todo.txt}"
echo ""
echo "✅ TODAY'S TASKS:"
if [ -f "$SCRIPT_DIR/todo.sh" ]; then
    "$SCRIPT_DIR/todo.sh" top 3
else
    echo "  (todo.sh not found)"
fi

# --- AI BRIEFING (Optional) ---
if [ "${AI_BRIEFING_ENABLED:-true}" = "true" ]; then
    echo ""
    echo "🤖 AI BRIEFING:"

    # Cache file for today's briefing
    BRIEFING_CACHE="${BRIEFING_CACHE_FILE:-$DATA_DIR/.ai_briefing_cache}"
    TODAY=$(date '+%Y-%m-%d')

    # Check if we already have today's briefing
    if [ -f "$BRIEFING_CACHE" ] && grep -q "^$TODAY|" "$BRIEFING_CACHE"; then
        echo "  (Cached from this morning)"
        grep "^$TODAY|" "$BRIEFING_CACHE" | cut -d'|' -f2- | sed 's/^/  /'
    else
        # Generate new briefing
        JOURNAL_FILE="${JOURNAL_FILE:-$DATA_DIR/journal.txt}"
        TODO_FILE="${TODO_FILE:-$DATA_DIR/todo.txt}"

        # Gather context
        FOCUS_CONTEXT=""
        if [ -f "$FOCUS_FILE" ] && [ -s "$FOCUS_FILE" ]; then
            FOCUS_CONTEXT=$(cat "$FOCUS_FILE")
        fi
        RECENT_JOURNAL=$(tail -n 5 "$JOURNAL_FILE" 2>/dev/null || echo "")
        TODAY_TASKS=$(head -n 5 "$TODO_FILE" 2>/dev/null || echo "")

        if command -v dhp-strategy.sh &> /dev/null; then
            # Generate briefing via AI
            BRIEFING=$({
                echo "Provide a morning briefing (3-4 sentences)."
                echo "Primary signals are today's focus and recent GitHub pushes; use them first."
                echo "Secondary signals are journal entries and the task list."
                echo ""
                echo "Today's focus:"
                echo "${FOCUS_CONTEXT:-"(no focus set)"}"
                echo ""
                echo "Recent GitHub pushes (last 7 days):"
                echo "${RECENT_PUSHES:-"(none)"}"
                echo ""
                echo "Recent journal entries:"
                echo "${RECENT_JOURNAL:-"(none)"}"
                echo ""
                echo "Top tasks:"
                echo "${TODAY_TASKS:-"(none)"}"
                echo ""
                echo "Provide:"
                echo "- A short reflection on what the recent pushes suggest about momentum"
                echo "- The smallest next step for today"
                echo "- One energy-protecting reminder"
            } | dhp-strategy.sh 2>/dev/null || echo "Unable to generate AI briefing at this time.")

            # Cache the briefing
            echo "$TODAY|$BRIEFING" > "$BRIEFING_CACHE"
            echo "$BRIEFING" | sed 's/^/  /'
        else
            echo "  (AI briefing unavailable: dhp-strategy.sh not found in PATH)"
        fi
    fi
fi

echo ""
echo "💡 Quick commands: todo add | journal | goto | backup"
echo "════════════════════════════════════════════════════════════"
