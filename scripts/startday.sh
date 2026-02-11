#!/usr/bin/env bash
set -euo pipefail
# startday.sh - Enhanced morning routine

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_LIB="$SCRIPT_DIR/lib/common.sh"
DATE_UTILS="$SCRIPT_DIR/lib/date_utils.sh"
CONFIG_LIB="$SCRIPT_DIR/lib/config.sh"

if [ -f "$COMMON_LIB" ]; then
    # shellcheck disable=SC1090
    source "$COMMON_LIB"
else
    echo "Error: common utilities not found at $COMMON_LIB" >&2
    exit 1
fi

if [ -f "$DATE_UTILS" ]; then
    # shellcheck disable=SC1090
    source "$DATE_UTILS"
else
    echo "Error: date utilities not found at $DATE_UTILS" >&2
    exit 1
fi

# --- CONFIGURATION ---
if [ -f "$CONFIG_LIB" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_LIB"
else
    echo "Error: configuration library not found at $CONFIG_LIB" >&2
    exit 1
fi

# Source new libraries
if [ -f "$SCRIPT_DIR/lib/github_ops.sh" ]; then
    source "$SCRIPT_DIR/lib/github_ops.sh"
fi
if [ -f "$SCRIPT_DIR/lib/health_ops.sh" ]; then
    source "$SCRIPT_DIR/lib/health_ops.sh"
fi
if [ -f "$SCRIPT_DIR/lib/coach_ops.sh" ]; then
    source "$SCRIPT_DIR/lib/coach_ops.sh"
fi

mkdir -p "$DATA_DIR"
CURRENT_DAY_FILE="$DATA_DIR/current_day"
BRIEFING_CACHE="$BRIEFING_CACHE_FILE"

# Support "refresh" to force new AI briefing.
# By default we keep GitHub cache so transient network failures still degrade gracefully.
if [[ "${1:-}" == "refresh" ]]; then
    rm -f "$BRIEFING_CACHE"
    if [[ "${2:-}" == "--clear-github-cache" ]]; then
        rm -rf "$GITHUB_CACHE_DIR"
        echo "🔄 Cache cleared (AI briefing + GitHub). Forcing new session data..."
    else
        echo "🔄 AI briefing cache cleared. Keeping GitHub cache for resilience."
    fi
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

# Coach mode prompt is resolved before heavy sections so briefing cannot block.
COACH_MODE_PREFILL="${AI_COACH_MODE_DEFAULT:-LOCKED}"
if [ "${AI_BRIEFING_ENABLED:-true}" = "true" ] && command -v coach_get_mode_for_date >/dev/null 2>&1; then
    TODAY_FOR_MODE=$(date '+%Y-%m-%d')
    if [ -t 0 ]; then
        COACH_MODE_PREFILL=$(coach_get_mode_for_date "$TODAY_FOR_MODE" "true" 2>/dev/null || echo "${AI_COACH_MODE_DEFAULT:-LOCKED}")
    else
        COACH_MODE_PREFILL=$(coach_get_mode_for_date "$TODAY_FOR_MODE" "false" 2>/dev/null || echo "${AI_COACH_MODE_DEFAULT:-LOCKED}")
    fi
fi

# --- LOGGING ---
SYSTEM_LOG_FILE="${SYSTEM_LOG_FILE:?SYSTEM_LOG_FILE is not set by config.sh}"
echo "$(date): startday.sh - Running morning routine." >> "$SYSTEM_LOG_FILE"

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
JOURNAL_FILE="${JOURNAL_FILE:?JOURNAL_FILE is not set by config.sh}"
YESTERDAY_JOURNAL_CONTEXT=""
echo ""
echo "📅 YESTERDAY YOU WERE:"
if [ -f "$JOURNAL_FILE" ]; then
    echo "Journal entries:"
    yesterday=$(date_shift_days -1 "%Y-%m-%d")
    yesterday_entries=$(awk -F'|' -v day="$yesterday" '$1 ~ "^"day {print "  • " $0}' "$JOURNAL_FILE")
    if [ -n "$yesterday_entries" ]; then
        echo "$yesterday_entries"
        YESTERDAY_JOURNAL_CONTEXT="$yesterday_entries"
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
YESTERDAY_COMMITS=""
if command -v get_commit_activity_for_date >/dev/null 2>&1; then
    yesterday_date=$(date_shift_days -1 "%Y-%m-%d")
    if YESTERDAY_COMMITS=$(get_commit_activity_for_date "$yesterday_date" 2>/dev/null); then
        if [ -n "$YESTERDAY_COMMITS" ]; then
            echo "$YESTERDAY_COMMITS"
        else
            echo "  (No commits for $yesterday_date)"
        fi
    else
        echo "  (Unable to fetch commit activity. Check your token or network.)"
    fi
else
    echo "  (GitHub operations library not loaded)"
fi

# --- SUGGESTED DIRECTORIES ---
echo ""
echo "💡 SUGGESTED DIRECTORIES:"
if [ -f "$SCRIPT_DIR/g.sh" ]; then
    suggested_dirs=$("$SCRIPT_DIR/g.sh" suggest 2>/dev/null | awk '
        {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^\//) {
                    print "  • " $i
                    break
                }
            }
        }
    ' | head -n 3 || true)
    if [ -n "$suggested_dirs" ]; then
        echo "$suggested_dirs"
    else
        echo "  (No suggestions available)"
    fi
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
STALE_TODO_FILE="$TODO_FILE"
echo ""
echo "⏰ STALE TASKS:"
if [ -f "$STALE_TODO_FILE" ] && [ -s "$STALE_TODO_FILE" ]; then
    CUTOFF_DATE=$(date_shift_days "-${STALE_TASK_DAYS:-7}" "%Y-%m-%d")
    awk -F'|' -v cutoff="$CUTOFF_DATE" '$1 < cutoff { printf "  • %s (from %s)\n", $2, $1 }' "$STALE_TODO_FILE"
fi

# --- TODAY'S TASKS ---
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
    BRIEFING_CACHE="$BRIEFING_CACHE_FILE"
    TODAY=$(date '+%Y-%m-%d')

    # Check if we already have today's briefing
    if [ -f "$BRIEFING_CACHE" ] && grep -q "^$TODAY|" "$BRIEFING_CACHE"; then
        echo "  (Cached from this morning)"
        CACHED_BRIEFING=$(grep "^$TODAY|" "$BRIEFING_CACHE" | tail -n 1 | cut -d'|' -f2- || true)
        CACHED_BRIEFING="${CACHED_BRIEFING//\\n/$'\n'}"
        echo "$CACHED_BRIEFING" | sed 's/^/  /'
    else
        # Generate new briefing
        # Gather context
        FOCUS_CONTEXT=""
        if [ -f "$FOCUS_FILE" ] && [ -s "$FOCUS_FILE" ]; then
            FOCUS_CONTEXT=$(cat "$FOCUS_FILE")
        fi
        RECENT_JOURNAL=$(tail -n 5 "$JOURNAL_FILE" 2>/dev/null || echo "")
        TODAY_TASKS=""
        if [ -x "$SCRIPT_DIR/todo.sh" ]; then
            TODAY_TASKS=$("$SCRIPT_DIR/todo.sh" top 3 2>/dev/null || true)
        fi
        if [ -z "$TODAY_TASKS" ]; then
            TODAY_TASKS=$(head -n 5 "$TODO_FILE" 2>/dev/null || echo "")
        fi
        BRIEFING_TEMPERATURE="${AI_BRIEFING_TEMPERATURE:-0.25}"
        COACH_TACTICAL_DAYS="${AI_COACH_TACTICAL_DAYS:-7}"
        COACH_PATTERN_DAYS="${AI_COACH_PATTERN_DAYS:-30}"
        COACH_MODE="${COACH_MODE_PREFILL:-${AI_COACH_MODE_DEFAULT:-LOCKED}}"
        COACH_TACTICAL_METRICS=""
        COACH_PATTERN_METRICS=""
        COACH_DATA_QUALITY_FLAGS=""
        COACH_BEHAVIOR_DIGEST="(behavior digest unavailable)"

        if command -v coach_collect_tactical_metrics >/dev/null 2>&1; then
            COACH_TACTICAL_METRICS=$(coach_collect_tactical_metrics "$TODAY" "$COACH_TACTICAL_DAYS" "${RECENT_PUSHES:-}" "${YESTERDAY_COMMITS:-}" 2>/dev/null || true)
        fi
        if command -v coach_collect_pattern_metrics >/dev/null 2>&1; then
            COACH_PATTERN_METRICS=$(coach_collect_pattern_metrics "$TODAY" "$COACH_PATTERN_DAYS" 2>/dev/null || true)
        fi
        if command -v coach_collect_data_quality_flags >/dev/null 2>&1; then
            COACH_DATA_QUALITY_FLAGS=$(coach_collect_data_quality_flags 2>/dev/null || true)
        fi
        if command -v coach_build_behavior_digest >/dev/null 2>&1; then
            COACH_BEHAVIOR_DIGEST=$(coach_build_behavior_digest "$TODAY" "$COACH_TACTICAL_DAYS" "$COACH_PATTERN_DAYS" 2>/dev/null || echo "(behavior digest unavailable)")
        fi

        if command -v dhp-strategy.sh &> /dev/null; then
            if command -v coach_build_startday_prompt >/dev/null 2>&1; then
                BRIEFING_PROMPT="$(coach_build_startday_prompt \
                    "${FOCUS_CONTEXT:-}" \
                    "${COACH_MODE:-LOCKED}" \
                    "${YESTERDAY_COMMITS:-}" \
                    "${RECENT_PUSHES:-}" \
                    "${RECENT_JOURNAL:-}" \
                    "${YESTERDAY_JOURNAL_CONTEXT:-}" \
                    "${TODAY_TASKS:-}" \
                    "${COACH_BEHAVIOR_DIGEST:-}")"
            else
                BRIEFING_PROMPT="Produce a high-signal morning execution guide grounded only in today's focus and top tasks."
            fi
            BRIEFING=""
            BRIEFING_REASON="ai-error"

            if command -v coach_strategy_with_retry >/dev/null 2>&1; then
                if BRIEFING=$(coach_strategy_with_retry "$BRIEFING_PROMPT" "$BRIEFING_TEMPERATURE" "${AI_COACH_REQUEST_TIMEOUT_SECONDS:-35}" "${AI_COACH_RETRY_TIMEOUT_SECONDS:-90}" 2>/dev/null); then
                    BRIEFING_REASON=""
                else
                    strategy_status=$?
                    if [ "$strategy_status" -eq 124 ]; then
                        BRIEFING_REASON="timeout"
                    else
                        BRIEFING_REASON="error"
                    fi
                fi
            else
                if BRIEFING=$(printf '%s' "$BRIEFING_PROMPT" | dhp-strategy.sh --temperature "$BRIEFING_TEMPERATURE" 2>/dev/null); then
                    BRIEFING_REASON=""
                else
                    BRIEFING_REASON="error"
                fi
            fi

            if [ -z "$BRIEFING" ]; then
                if command -v coach_startday_fallback_output >/dev/null 2>&1; then
                    BRIEFING=$(coach_startday_fallback_output "${FOCUS_CONTEXT:-"(no focus set)"}" "$COACH_MODE" "${TODAY_TASKS:-}" "${BRIEFING_REASON:-unavailable}")
                else
                    BRIEFING="Unable to generate AI briefing at this time."
                fi
            elif [ -z "$BRIEFING_REASON" ] && command -v coach_startday_response_is_grounded >/dev/null 2>&1; then
                if ! coach_startday_response_is_grounded "$BRIEFING" "${FOCUS_CONTEXT:-"(no focus set)"}" "${TODAY_TASKS:-}"; then
                    BRIEFING_REASON="ungrounded-actions"
                    if command -v coach_startday_fallback_output >/dev/null 2>&1; then
                        BRIEFING=$(coach_startday_fallback_output "${FOCUS_CONTEXT:-"(no focus set)"}" "$COACH_MODE" "${TODAY_TASKS:-}" "$BRIEFING_REASON")
                    fi
                fi
            fi
        else
            if command -v coach_startday_fallback_output >/dev/null 2>&1; then
                BRIEFING=$(coach_startday_fallback_output "${FOCUS_CONTEXT:-"(no focus set)"}" "$COACH_MODE" "${TODAY_TASKS:-}" "dispatcher-missing")
            else
                BRIEFING="Unable to generate AI briefing at this time."
            fi
        fi

        BRIEFING_ESCAPED="${BRIEFING//$'\n'/\\n}"
        printf '%s|%s\n' "$TODAY" "$BRIEFING_ESCAPED" > "$BRIEFING_CACHE"
        echo "$BRIEFING" | sed 's/^/  /'

        if command -v coach_append_log >/dev/null 2>&1; then
            COACH_METRICS_PAYLOAD="tactical:$(printf '%s' "$COACH_TACTICAL_METRICS" | tr '\n' ';') pattern:$(printf '%s' "$COACH_PATTERN_METRICS" | tr '\n' ';') quality:$(printf '%s' "$COACH_DATA_QUALITY_FLAGS" | tr '\n' ';')"
            coach_append_log "STARTDAY" "$TODAY" "$COACH_MODE" "${FOCUS_CONTEXT:-"(no focus set)"}" "$COACH_METRICS_PAYLOAD" "$BRIEFING" || true
        fi
    fi
fi

echo ""
echo "💡 Quick commands: todo add | journal | goto | backup"
echo "════════════════════════════════════════════════════════════"
