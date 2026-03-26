#!/usr/bin/env bash
set -euo pipefail
# startday.sh - Enhanced morning routine

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/loader.sh" || exit 1

mkdir -p "$DATA_DIR"
CURRENT_DAY_FILE="$DATA_DIR/current_day"
BRIEFING_CACHE="$BRIEFING_CACHE_FILE"

# Refresh Fitbit data before the morning summary begins.
# We do this early so the health summary and AI briefing can use the newest sleep,
# steps, heart rate, and HRV numbers. If sync fails, we keep going.
if command -v health_ops_auto_sync_fitbit >/dev/null 2>&1; then
    health_ops_auto_sync_fitbit >/dev/null 2>&1 || true
fi

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
date_today > "$CURRENT_DAY_FILE"

CONTEXT_CAPTURE_ON_START="${CONTEXT_CAPTURE_ON_START:-false}"
if [ "$CONTEXT_CAPTURE_ON_START" = "true" ]; then
    CONTEXT_SCRIPT="$SCRIPT_DIR/context.sh"
    if [ -x "$CONTEXT_SCRIPT" ]; then
        "$CONTEXT_SCRIPT" capture "startday-$(date_now '%Y%m%d-%H%M')" >/dev/null 2>&1 || true
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
        _sd_depletion=""
        if [ -z "$(command -v predict_spoon_depletion)" ] && [ -f "$SCRIPT_DIR/lib/spoon_budget.sh" ]; then
            # shellcheck disable=SC1090
            source "$SCRIPT_DIR/lib/spoon_budget.sh"
        fi
        if command -v predict_spoon_depletion >/dev/null 2>&1; then
            _sd_depletion=$(predict_spoon_depletion 2>/dev/null || true)
        fi
        if [ -n "$_sd_depletion" ]; then
            echo "  You have $remaining spoons remaining today (at current rate, $_sd_depletion)."
        else
            echo "  You have $remaining spoons remaining today."
        fi
        if [ -t 0 ]; then
            echo -n "  Update spoon budget? [y/N]: "
            read -r update_spoons
            if [[ "$update_spoons" =~ ^[yY] ]]; then
                echo -n "  How many spoons do you have today? [10]: "
                read -r spoons_input
                spoons_count="${spoons_input:-10}"
                if ! validate_numeric "$spoons_count" "spoon count" >/dev/null 2>&1; then
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

        if ! validate_numeric "$spoons_count" "spoon count" >/dev/null 2>&1; then
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
if [ "${AI_BRIEFING_ENABLED:-true}" = "true" ] && command -v coaching_get_mode_for_date >/dev/null 2>&1; then
    TODAY_FOR_MODE=$(date_today)
    if [ -t 0 ]; then
        COACH_MODE_PREFILL=$(coaching_get_mode_for_date "$TODAY_FOR_MODE" "true" 2>/dev/null || echo "${AI_COACH_MODE_DEFAULT:-LOCKED}")
    else
        COACH_MODE_PREFILL=$(coaching_get_mode_for_date "$TODAY_FOR_MODE" "false" 2>/dev/null || echo "${AI_COACH_MODE_DEFAULT:-LOCKED}")
    fi
fi

# --- LOGGING ---
SYSTEM_LOG_FILE="${SYSTEM_LOG_FILE:?SYSTEM_LOG_FILE is not set by config.sh}"
echo "$(date_now): startday.sh - Running morning routine." >> "$SYSTEM_LOG_FILE"

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

# --- TOMORROW'S LAUNCHPAD (Yesterday's prep) ---
LAUNCHPAD_FILE="$DATA_DIR/tomorrow_launchpad"
if [ -f "$LAUNCHPAD_FILE" ]; then
    echo ""
    echo "🚀 YESTERDAY'S PREP FOR TODAY:"
    # Extract the Tomorrow lock section or show everything if small.
    awk '/Tomorrow lock:/,EOF' "$LAUNCHPAD_FILE" | sed 's/^/  /' || true
fi

# --- WEEKLY REVIEW ---
if [ "$(date_weekday_iso)" -eq 1 ]; then
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
RECENT_PUSHES=""
if command -v get_recent_github_activity >/dev/null 2>&1; then
    if RECENT_PUSHES=$(get_recent_github_activity 7); then
        if [ -n "$RECENT_PUSHES" ]; then
            echo "$RECENT_PUSHES"
        else
            echo "  (No recent pushes)"
        fi
    else
        echo "  (Unable to fetch GitHub activity. Check your token or network.)"
        RECENT_PUSHES="(GitHub signal unavailable)"
    fi
else
    echo "  (GitHub operations library not loaded)"
    RECENT_PUSHES="(GitHub signal unavailable)"
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
        YESTERDAY_COMMITS="(GitHub signal unavailable)"
    fi
else
    echo "  (GitHub operations library not loaded)"
    YESTERDAY_COMMITS="(GitHub signal unavailable)"
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

# --- STALE TASKS (older than 7 days) ---
STALE_TODO_FILE="$TODO_FILE"
ensure_todo_migrated
echo ""
echo "⏰ STALE TASKS:"
if [ -f "$STALE_TODO_FILE" ] && [ -s "$STALE_TODO_FILE" ]; then
    CUTOFF_DATE=$(date_shift_days "-${STALE_TASK_DAYS}" "%Y-%m-%d")
    awk -F'|' -v cutoff="$CUTOFF_DATE" '$2 < cutoff { printf "  • %s (from %s)\n", $3, $2 }' "$STALE_TODO_FILE"
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

    # This whole block does four jobs:
    # 1. gather facts,
    # 2. build an AI prompt,
    # 3. ask the AI for a briefing,
    # 4. save the answer so we do not ask again the same morning.

    # Cache file for today's briefing
    BRIEFING_CACHE="$BRIEFING_CACHE_FILE"
    TODAY=$(date_today)

    # Check if we already have today's briefing
    if [ -f "$BRIEFING_CACHE" ] && grep -q "^$TODAY|" "$BRIEFING_CACHE"; then
        echo "  (Cached from this morning)"
        CACHED_BRIEFING=$(grep "^$TODAY|" "$BRIEFING_CACHE" | tail -n 1 | cut -d'|' -f2- || true)
        CACHED_BRIEFING="${CACHED_BRIEFING//\\n/$'\n'}"
        echo "$CACHED_BRIEFING" | sed 's/^/  /'
        echo "  (Signal: CACHED - briefing from earlier today)"
        _COACH_CHAT_BRIEFING="$CACHED_BRIEFING"
    else
        # No cached morning briefing yet, so we build a fresh one.
        # First we gather the facts the AI is allowed to use.
        FOCUS_CONTEXT=""
        if [ -f "$FOCUS_FILE" ] && [ -s "$FOCUS_FILE" ]; then
            FOCUS_CONTEXT=$(cat "$FOCUS_FILE")
        fi
        BRIEFING_TEMPERATURE="${AI_BRIEFING_TEMPERATURE:-0.25}"
        COACH_TACTICAL_DAYS="${AI_COACH_TACTICAL_DAYS:-7}"
        COACH_PATTERN_DAYS="${AI_COACH_PATTERN_DAYS:-30}"
        COACH_MODE="${COACH_MODE_PREFILL:-${AI_COACH_MODE_DEFAULT:-LOCKED}}"
        COACH_TACTICAL_METRICS=""
        COACH_PATTERN_METRICS=""
        COACH_DATA_QUALITY_FLAGS=""
        COACH_BEHAVIOR_DIGEST="(behavior digest unavailable)"

        if command -v coaching_collect_tactical_metrics >/dev/null 2>&1; then
            COACH_TACTICAL_METRICS=$(coaching_collect_tactical_metrics "$TODAY" "$COACH_TACTICAL_DAYS" "${RECENT_PUSHES:-}" "${YESTERDAY_COMMITS:-}" 2>/dev/null || true)
        fi
        if command -v coaching_collect_pattern_metrics >/dev/null 2>&1; then
            COACH_PATTERN_METRICS=$(coaching_collect_pattern_metrics "$TODAY" "$COACH_PATTERN_DAYS" 2>/dev/null || true)
        fi
        if command -v coaching_collect_data_quality_flags >/dev/null 2>&1; then
            COACH_DATA_QUALITY_FLAGS=$(coaching_collect_data_quality_flags 2>/dev/null || true)
        fi
        # The behavior digest is the condensed "fact sheet" for the coach.
        # It now includes wearable context too, when Fitbit data exists.
        if command -v coaching_build_behavior_digest >/dev/null 2>&1; then
            COACH_BEHAVIOR_DIGEST=$(coaching_build_behavior_digest "$TODAY" "$COACH_TACTICAL_DAYS" "$COACH_PATTERN_DAYS" "${RECENT_PUSHES:-}" "${YESTERDAY_COMMITS:-}" 2>/dev/null || echo "(behavior digest unavailable)")
        fi

        _sd_git_combined=$(printf '%s\n%s\n' "${YESTERDAY_COMMITS:-}" "${RECENT_PUSHES:-}")

        # Next we turn all those facts into one clear instruction packet for the AI.
        if command -v coaching_build_startday_prompt >/dev/null 2>&1; then
            BRIEFING_PROMPT="$(coaching_build_startday_prompt \
                "${FOCUS_CONTEXT:-}" \
                "${COACH_MODE:-LOCKED}" \
                "${YESTERDAY_COMMITS:-}" \
                "${RECENT_PUSHES:-}" \
                "${COACH_BEHAVIOR_DIGEST:-}")"
        else
            BRIEFING_PROMPT="Produce a high-signal morning execution guide grounded only in today's focus and GitHub activity."
        fi

        # Now we ask the AI to write the actual morning briefing.
        if command -v coaching_generate_response >/dev/null 2>&1; then
            BRIEFING=$(coaching_generate_response "$BRIEFING_PROMPT" "$BRIEFING_TEMPERATURE" "${FOCUS_CONTEXT:-"(no focus set)"}" "$COACH_MODE" "$_sd_git_combined" "${COACH_BEHAVIOR_DIGEST:-}" "startday")
        else
            BRIEFING="Unable to generate AI briefing at this time."
        fi

        # Save today's answer so repeat runs can reuse it instead of re-calling the AI.
        BRIEFING_ESCAPED="${BRIEFING//$'\n'/\\n}"
        printf '%s|%s\n' "$TODAY" "$BRIEFING_ESCAPED" > "$BRIEFING_CACHE"
        echo "$BRIEFING" | sed 's/^/  /'
        _COACH_CHAT_BRIEFING="$BRIEFING"

        # This confidence summary is a quick report card for the briefing itself.
        # It tells the user whether the coach had lots of evidence or only a little.
        _sd_present=0
        _sd_reasons=()
        if [ -n "${FOCUS_CONTEXT:-}" ]; then
            _sd_present=$((_sd_present + 1))
        else
            _sd_reasons+=("no focus")
        fi
        if [[ "${YESTERDAY_COMMITS:-}" == *"GitHub signal unavailable"* ]] || [[ "${RECENT_PUSHES:-}" == *"GitHub signal unavailable"* ]]; then
            _sd_reasons+=("github signal unavailable")
        elif { [ -n "${YESTERDAY_COMMITS:-}" ] && [ "$YESTERDAY_COMMITS" != "(none)" ]; } || { [ -n "${RECENT_PUSHES:-}" ] && [ "$RECENT_PUSHES" != "(none)" ]; }; then
            _sd_present=$((_sd_present + 1))
        else
            _sd_reasons+=("no non-fork github momentum")
        fi
        if [ -f "${HEALTH_FILE:-}" ] && [ -s "${HEALTH_FILE:-}" ]; then
            _sd_present=$((_sd_present + 1))
        else
            _sd_reasons+=("no health logs")
        fi
        if [ "${COACH_BEHAVIOR_DIGEST:-}" != "(behavior digest unavailable)" ]; then
            _sd_present=$((_sd_present + 1))
        else
            _sd_reasons+=("no behavior digest")
        fi

        _sd_signal_confidence="LOW"
        if [ "${_sd_present:-0}" -ge 4 ] && [ "${#_sd_reasons[@]}" -eq 0 ]; then
            _sd_signal_confidence="HIGH"
        elif [ "${_sd_present:-0}" -ge 3 ]; then
            _sd_signal_confidence="MEDIUM"
        fi
        if [ "${#_sd_reasons[@]}" -eq 0 ]; then
            _sd_signal_reason_text="all primary sources available"
        else
            _sd_signal_reason_text=$(printf '%s' "${_sd_reasons[0]}")
            for _reason in "${_sd_reasons[@]:1}"; do
                _sd_signal_reason_text="${_sd_signal_reason_text}, ${_reason}"
            done
        fi
        printf '  (Signal: %s - %s)\n' "$_sd_signal_confidence" "$_sd_signal_reason_text"

        if command -v coaching_append_log >/dev/null 2>&1; then
            COACH_METRICS_PAYLOAD="tactical:$(printf '%s' "$COACH_TACTICAL_METRICS" | tr '\n' ';') pattern:$(printf '%s' "$COACH_PATTERN_METRICS" | tr '\n' ';') quality:$(printf '%s' "$COACH_DATA_QUALITY_FLAGS" | tr '\n' ';')"
            coaching_append_log "STARTDAY" "$TODAY" "$COACH_MODE" "${FOCUS_CONTEXT:-"(no focus set)"}" "$COACH_METRICS_PAYLOAD" "$BRIEFING" || true
        fi
    fi
fi

# Interactive coach chat (on by default; disable with AI_COACH_CHAT_ENABLED=false)
if [[ -n "${_COACH_CHAT_BRIEFING:-}" ]] && type coach_start_chat >/dev/null 2>&1; then
    coach_start_chat "$_COACH_CHAT_BRIEFING" "startday"
fi

echo ""
echo "💡 Quick commands: todo add | journal | goto | backup"
echo "════════════════════════════════════════════════════════════"
