#!/bin/bash
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
    STATE_DIR="${STATE_DIR:-$HOME/.config/dotfiles-data}"
    CURRENT_DAY_FILE="$STATE_DIR/current_day"
    # Ensure exports for compatibility if config missing
    export FOCUS_FILE="$STATE_DIR/daily_focus.txt"
fi

# Compatibility: Map config.sh vars to local expectation if needed
# config.sh uses DATA_DIR, startday uses STATE_DIR
STATE_DIR="${DATA_DIR:-${STATE_DIR:-$HOME/.config/dotfiles-data}}"

mkdir -p "$STATE_DIR"
CURRENT_DAY_FILE="${CURRENT_DAY_FILE:-$STATE_DIR/current_day}"
FOCUS_FILE="${FOCUS_FILE:-$STATE_DIR/daily_focus.txt}"
BRIEFING_CACHE="${BRIEFING_CACHE_FILE:-$STATE_DIR/.ai_briefing_cache}"

# Support "refresh" to force new AI briefing
if [[ "${1:-}" == "refresh" ]]; then
    rm -f "$BRIEFING_CACHE"
    echo "🔄 Cache cleared. Forcing new session data..."
fi

# Persist the start date of this session
date +%Y-%m-%d > "$CURRENT_DAY_FILE"

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
    if ! "$SPOON_MANAGER" check &>/dev/null; then
        # Not initialized yet - prompt for spoons
        # Check if running interactively
        if [ -t 0 ]; then
            echo -n "  How many spoons do you have today? [12]: "
            read -r spoons_input
            spoons_count="${spoons_input:-12}"
        else
            echo "  (Non-interactive mode: defaulting to 12)"
            spoons_count=12
        fi

        if ! [[ "$spoons_count" =~ ^[0-9]+$ ]]; then
            echo "  Invalid input, defaulting to 12."
            spoons_count=12
        fi

        "$SPOON_MANAGER" init "$spoons_count" | sed 's/^/  /'
    else
        # Already initialized, just show status
        remaining=$("$SPOON_MANAGER" check | grep -oE '[0-9]+' || echo "?")
        echo "  You have $remaining spoons remaining today."
    fi
else
    echo "  (Spoon manager not found)"
fi

# --- LOGGING ---
SYSTEM_LOG_FILE="${SYSTEM_LOG:-$STATE_DIR/system.log}"
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
JOURNAL_FILE="${JOURNAL_FILE:-$STATE_DIR/journal.txt}"
echo ""
echo "📅 YESTERDAY YOU WERE:"
# Show last 3 journal entries or git commits
if [ -f "$JOURNAL_FILE" ]; then
    echo "Journal entries:"
    tail -n 3 "$JOURNAL_FILE" | sed 's/^/  • /'
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
HELPER_SCRIPT="$SCRIPT_DIR/github_helper.sh"
RECENT_PUSHES=""
if [ -f "$HELPER_SCRIPT" ]; then
    if ! command -v jq >/dev/null 2>&1; then
        echo "  ⚠️ jq not found; cannot parse GitHub activity."
    elif GITHUB_REPOS=$("$HELPER_SCRIPT" list_repos 2>/dev/null); then
        repo_lines=$(echo "$GITHUB_REPOS" | jq -r '.[] | "\(.pushed_at) \(.name)"')
        while read -r line; do
            [ -z "$line" ] && continue
            pushed_at_str=$(echo "$line" | awk '{print $1}')
            repo_name=$(echo "$line" | awk '{$1=""; print $0}' | xargs) # handle repo names with spaces

            pushed_at_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$pushed_at_str" +%s 2>/dev/null || continue)
            NOW=$(date +%s)
            DAYS_AGO=$(( (NOW - pushed_at_epoch) / 86400 ))

            if [ "$DAYS_AGO" -le 7 ]; then
                if [ "$DAYS_AGO" -eq 0 ]; then
                    day_text="today"
                elif [ "$DAYS_AGO" -eq 1 ]; then
                    day_text="yesterday"
                else
                    day_text="$DAYS_AGO days ago"
                fi
                entry="$repo_name (pushed $day_text)"
                echo "  • $entry"
                RECENT_PUSHES+="${entry}"$'\n'
            else
                break
            fi
        done <<< "$repo_lines"
    else
        echo "  ⚠️ Unable to fetch GitHub activity. Check your token or network."
    fi
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
parse_timestamp() {
    local raw="$1"
    local epoch
    epoch=$(timestamp_to_epoch "$raw")
    echo "${epoch:-0}"
}

# --- HEALTH ---
echo ""
echo "🏥 HEALTH:"
HEALTH_FILE="${HEALTH_FILE:-$STATE_DIR/health.txt}"
if [ -f "$HEALTH_FILE" ] && [ -s "$HEALTH_FILE" ]; then
    # Show upcoming appointments
    TODAY_STR=$(date +%Y-%m-%d)
    TODAY_EPOCH=$(parse_timestamp "$TODAY_STR")
    
    if grep -q "^APPT|" "$HEALTH_FILE" 2>/dev/null; then
        grep "^APPT|" "$HEALTH_FILE" | sort -t'|' -k2 | while IFS='|' read -r type appt_date desc; do
            appt_epoch=$(parse_timestamp "$appt_date")
            if [ "$appt_epoch" -le 0 ]; then
                continue
            fi
            
            # Calculate difference in days (Midnight to Midnight)
            # Add partial day rounding just in case, but usually integer division of 86400 works for dates
            diff_seconds=$(( appt_epoch - TODAY_EPOCH ))
            days_until=$(( diff_seconds / 86400 ))
            
            if [ "$days_until" -ge 0 ]; then
                if [ "$days_until" -eq 1 ]; then
                     echo "  • $desc - $appt_date (Tomorrow)"
                elif [ "$days_until" -eq 0 ]; then
                     echo "  • $desc - $appt_date (Today)"
                else
                     echo "  • $desc - $appt_date (in $days_until days)"
                fi
            fi
        done
    fi

    # Show today's health snapshot if available
    today=$(date '+%Y-%m-%d')
    if grep -q "^ENERGY|$today" "$HEALTH_FILE" 2>/dev/null; then
        today_energy=$(grep "^ENERGY|$today" "$HEALTH_FILE" | tail -1 | cut -d'|' -f3)
        echo "  Energy level: $today_energy/10"
    fi

    if grep -q "^SYMPTOM|$today" "$HEALTH_FILE" 2>/dev/null; then
        symptom_count=$(grep -c "^SYMPTOM|$today" "$HEALTH_FILE")
        echo "  Symptoms logged today: $symptom_count (run 'health list' to see)"
    fi

    # If no data shown, display help
    if ! grep -q "^APPT\|^ENERGY\|^SYMPTOM" "$HEALTH_FILE" 2>/dev/null; then
        echo "  (no data tracked - try: health add, health energy, health symptom)"
    fi
else
    echo "  (no data tracked - try: health add, health energy, health symptom)"
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
STALE_TODO_FILE="${TODO_FILE:-$STATE_DIR/todo.txt}"
echo ""
echo "⏰ STALE TASKS:"
if [ -f "$STALE_TODO_FILE" ] && [ -s "$STALE_TODO_FILE" ]; then
    CUTOFF_DATE=$(date_shift_days "-${STALE_TASK_DAYS:-7}" "%Y-%m-%d")
    awk -F'|' -v cutoff="$CUTOFF_DATE" '$1 < cutoff { printf "  • %s (from %s)\n", $2, $1 }' "$STALE_TODO_FILE"
fi

# --- TODAY'S TASKS ---
TODO_FILE="${TODO_FILE:-$STATE_DIR/todo.txt}"
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
    BRIEFING_CACHE="${BRIEFING_CACHE_FILE:-$STATE_DIR/.ai_briefing_cache}"
    TODAY=$(date '+%Y-%m-%d')

    # Check if we already have today's briefing
    if [ -f "$BRIEFING_CACHE" ] && grep -q "^$TODAY|" "$BRIEFING_CACHE"; then
        echo "  (Cached from this morning)"
        grep "^$TODAY|" "$BRIEFING_CACHE" | cut -d'|' -f2- | sed 's/^/  /'
    else
        # Generate new briefing
        JOURNAL_FILE="${JOURNAL_FILE:-$STATE_DIR/journal.txt}"
        TODO_FILE="${TODO_FILE:-$STATE_DIR/todo.txt}"

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
