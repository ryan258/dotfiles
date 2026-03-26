#!/usr/bin/env bash
set -euo pipefail
# status.sh - Provides a mid-day context recovery dashboard.

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/loader.sh" || exit 1

FOCUS_FILE="${FOCUS_FILE:?FOCUS_FILE is not set by config.sh}"
JOURNAL_FILE="${JOURNAL_FILE:?JOURNAL_FILE is not set by config.sh}"
TODO_FILE="${TODO_FILE:?TODO_FILE is not set by config.sh}"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/Projects}"

_status_extract_repo_name_from_line() {
    local raw_line="$1"
    local cleaned=""

    cleaned=$(_status_trim_ascii_whitespace "$raw_line")
    case "$cleaned" in
        '• '*)
            cleaned=${cleaned#'• '}
            ;;
        '- '*)
            cleaned=${cleaned#'- '}
            ;;
    esac
    cleaned=$(_status_trim_ascii_whitespace "$cleaned")
    if [[ -z "$cleaned" || "$cleaned" == \(* ]]; then
        return 0
    fi
    if [[ "$cleaned" == *"|"* ]]; then
        printf '%s\n' "${cleaned%%|*}"
        return 0
    fi
    if [[ "$cleaned" == *":"* ]]; then
        printf '%s\n' "${cleaned%%:*}"
        return 0
    fi
    if [[ "$cleaned" == *" ("* ]]; then
        cleaned="${cleaned%% \(*}"
    fi
    printf '%s\n' "$cleaned"
}

_status_trim_ascii_whitespace() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

_status_filter_activity_for_repo() {
    local activity="$1"
    local repo_name="$2"
    local filtered=""
    local line=""
    local line_repo=""

    if [[ -z "$repo_name" || -z "$activity" ]]; then
        printf '%s' "$activity"
        return 0
    fi
    case "$activity" in
        "(none)"|"(GitHub signal unavailable)")
            printf '%s' "$activity"
            return 0
            ;;
    esac

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        line_repo=$(_status_extract_repo_name_from_line "$line")
        if [[ "$line_repo" == "$repo_name" ]]; then
            if [[ -n "$filtered" ]]; then
                filtered="${filtered}"$'\n'"$line"
            else
                filtered="$line"
            fi
        fi
    done <<< "$activity"

    if [[ -n "$filtered" ]]; then
        printf '%s' "$filtered"
    else
        printf '%s' "(none)"
    fi
}

STATUS_COACH_ENABLED="${AI_STATUS_ENABLED:-false}"
case "${1:-}" in
    --coach)
        STATUS_COACH_ENABLED=true
        ;;
    "")
        ;;
    *)
        die "Usage: status.sh [--coach]" "$EXIT_INVALID_ARGS"
        ;;
esac

# Refresh wearable data before building the mid-day dashboard.
# This helps the coach talk about your newest body signals instead of stale ones.
# Any sync error is ignored so `status.sh` still works as a recovery tool.
if command -v health_ops_auto_sync_fitbit >/dev/null 2>&1; then
    health_ops_auto_sync_fitbit >/dev/null 2>&1 || true
fi

_status_today=$(date_today)
CURRENT_DIR=$(pwd)
_status_project_context="(no project context)"
_status_git_repo_focus=false
_status_git_toplevel=""
if _status_git_toplevel=$(git rev-parse --show-toplevel 2>/dev/null); then
    _status_project_context=$(basename "$_status_git_toplevel")
    _status_git_repo_focus=true
elif [[ "$CURRENT_DIR" == "$PROJECTS_DIR"* ]]; then
    _status_project_context=$(basename "$CURRENT_DIR")
fi

STATUS_TODAY_COMMITS=""
if command -v get_commit_activity_for_date >/dev/null 2>&1; then
    if ! STATUS_TODAY_COMMITS=$(get_commit_activity_for_date "$_status_today" 2>/dev/null); then
        STATUS_TODAY_COMMITS="(GitHub signal unavailable)"
    elif [ -z "$STATUS_TODAY_COMMITS" ]; then
        STATUS_TODAY_COMMITS="(none)"
    fi
else
    STATUS_TODAY_COMMITS="(GitHub signal unavailable)"
fi

STATUS_RECENT_PUSHES=""
if command -v get_recent_github_activity >/dev/null 2>&1; then
    if ! STATUS_RECENT_PUSHES=$(get_recent_github_activity 7 2>/dev/null); then
        STATUS_RECENT_PUSHES="(GitHub signal unavailable)"
    elif [ -z "$STATUS_RECENT_PUSHES" ]; then
        STATUS_RECENT_PUSHES="(none)"
    fi
else
    STATUS_RECENT_PUSHES="(GitHub signal unavailable)"
fi

STATUS_COACH_TODAY_COMMITS="${STATUS_TODAY_COMMITS:-}"
STATUS_COACH_RECENT_PUSHES="${STATUS_RECENT_PUSHES:-}"
_status_context_scope="global"
if [[ "$_status_git_repo_focus" == "true" ]] && [[ "${_status_project_context:-}" != "(no project context)" ]]; then
    STATUS_COACH_TODAY_COMMITS=$(_status_filter_activity_for_repo "${STATUS_TODAY_COMMITS:-}" "${_status_project_context:-}")
    STATUS_COACH_RECENT_PUSHES=$(_status_filter_activity_for_repo "${STATUS_RECENT_PUSHES:-}" "${_status_project_context:-}")
    _status_context_scope="repo-local"
fi
_status_combined_git=$(printf '%s\n%s\n' "${STATUS_COACH_TODAY_COMMITS:-}" "${STATUS_COACH_RECENT_PUSHES:-}")

# --- Focus ---
echo ""
echo "🎯 TODAY'S FOCUS:"
_status_focus_text=""
if [ -f "$FOCUS_FILE" ] && [ -s "$FOCUS_FILE" ]; then
    _status_focus_text=$(cat "$FOCUS_FILE")
    echo "  $_status_focus_text"
else
    echo "  (No focus set)"
fi

# --- Daily Context ---
echo ""
echo "📊 DAILY CONTEXT:"
_status_mode="unknown"
if [ -f "${COACH_MODE_FILE:-}" ]; then
    _status_mode_line=$(grep "^${_status_today}|" "$COACH_MODE_FILE" 2>/dev/null | tail -1 || true)
    if [ -n "$_status_mode_line" ]; then
        _status_mode=$(echo "$_status_mode_line" | cut -d'|' -f2)
    else
        _status_mode="${AI_COACH_MODE_DEFAULT:-LOCKED}"
    fi
else
    _status_mode="${AI_COACH_MODE_DEFAULT:-LOCKED}"
fi
_status_spoons="?"
_status_budget="${DEFAULT_DAILY_SPOONS:-10}"
if command -v get_remaining_spoons >/dev/null 2>&1; then
    _status_spoons=$(get_remaining_spoons 2>/dev/null || echo "?")
    [ -z "$_status_spoons" ] && _status_spoons="?"
fi
if [ -f "${SPOON_LOG:-}" ]; then
    _budget_line=$(grep "^BUDGET|${_status_today}|" "$SPOON_LOG" 2>/dev/null | tail -1 || true)
    if [ -n "$_budget_line" ]; then
        _status_budget=$(echo "$_budget_line" | cut -d'|' -f3)
    fi
fi
_status_depletion=""
if command -v predict_spoon_depletion >/dev/null 2>&1; then
    _status_depletion=$(predict_spoon_depletion 2>/dev/null || true)
fi
_status_focus_label="${_status_focus_text:-"(none set)"}"
_status_alignment="no focus set"
if [ -n "$_status_focus_text" ] && command -v coach_focus_git_signal >/dev/null 2>&1; then
    _status_git_metrics=$(coach_focus_git_signal "$_status_focus_text" "${STATUS_RECENT_PUSHES:-}" "${STATUS_TODAY_COMMITS:-}" 2>/dev/null || true)
    _status_git_state=$(printf '%s\n' "$_status_git_metrics" | awk -F'=' '$1 == "focus_git_status" {print $2; exit}')
    _status_git_repo=$(printf '%s\n' "$_status_git_metrics" | awk -F'=' '$1 == "focus_git_primary_repo" {print $2; exit}')
    _status_git_repo_share=$(printf '%s\n' "$_status_git_metrics" | awk -F'=' '$1 == "focus_git_primary_repo_share" {print $2; exit}')
    _status_git_commit_pct=$(printf '%s\n' "$_status_git_metrics" | awk -F'=' '$1 == "focus_git_commit_coherence" {print $2; exit}')
    _status_git_repo_count=$(printf '%s\n' "$_status_git_metrics" | awk -F'=' '$1 == "focus_git_repo_count" {print $2; exit}')
    case "${_status_git_state:-}" in
        aligned)
            _status_alignment="aligned via ${_status_git_repo:-N/A} (${_status_git_commit_pct:-N/A}% commit coherence; ${_status_git_repo_count:-0} repo active)"
            ;;
        mixed)
            _status_alignment="mixed via ${_status_git_repo:-N/A} (${_status_git_commit_pct:-N/A}% commit coherence; ${_status_git_repo_count:-0} repos active)"
            ;;
        diffuse)
            _status_alignment="diffuse (${_status_git_commit_pct:-N/A}% commit coherence; ${_status_git_repo_count:-0} repos active)"
            ;;
        repo-locked)
            _status_alignment="repo-locked via ${_status_git_repo:-N/A} (${_status_git_repo_share:-N/A}% of observed activity)"
            ;;
        no-git-evidence)
            _status_alignment="no non-fork Git evidence yet"
            ;;
        git-unavailable)
            _status_alignment="GitHub signal unavailable"
            ;;
        *)
            _status_alignment="signal unavailable"
            ;;
    esac
elif [ -n "$_status_focus_text" ] && command -v coach_focus_coherence >/dev/null 2>&1; then
    _status_focus_metrics=$(coach_focus_coherence "$_status_focus_text" "$(date_today)" "false" 2>/dev/null || true)
    _status_focus_pct=$(printf '%s\n' "$_status_focus_metrics" | awk -F'=' '$1 == "focus_coherence_pct" {print $2; exit}')
    _status_focus_detail=$(printf '%s\n' "$_status_focus_metrics" | awk -F'=' '$1 == "focus_coherence_detail" {print $2; exit}')
    if [[ "${_status_focus_pct:-}" =~ ^[0-9]+$ ]]; then
        _status_alignment="task-fallback ${_status_focus_pct}% (${_status_focus_detail:-items})"
    elif [ -n "${_status_focus_detail:-}" ]; then
        _status_alignment="task-fallback N/A (${_status_focus_detail})"
    fi
fi
if [ -n "$_status_depletion" ]; then
    echo "  Mode: ${_status_mode} | Spoons: ${_status_spoons}/${_status_budget} remaining (${_status_depletion}) | Focus: ${_status_focus_label}"
else
    echo "  Mode: ${_status_mode} | Spoons: ${_status_spoons}/${_status_budget} remaining | Focus: ${_status_focus_label}"
fi
echo "  Spear alignment: ${_status_alignment}"

if [[ "$STATUS_COACH_ENABLED" == "true" ]]; then
    echo ""
    echo "🤖 STATUS COACH:"
    # Mid-day coaching is simpler than morning/evening:
    # gather the digest, build a short prompt, ask for one recentering brief.
    _status_behavior_digest="(behavior digest unavailable)"
    _status_prompt=""
    _status_briefing=""
    _status_reason="ai-error"
    _status_reason_detail=""
    _status_temperature="${AI_STATUS_TEMPERATURE:-${AI_BRIEFING_TEMPERATURE:-0.25}}"
    _status_dispatcher=""
    _status_exit_code=0

    # Build the same shared fact sheet used by the other coach flows.
    # This is where fresh Fitbit data gets folded into the AI context.
    if command -v coaching_build_behavior_digest >/dev/null 2>&1; then
        _status_behavior_digest=$(coaching_build_behavior_digest "$_status_today" "${AI_COACH_TACTICAL_DAYS:-7}" "${AI_COACH_PATTERN_DAYS:-30}" "${STATUS_COACH_RECENT_PUSHES:-}" "${STATUS_COACH_TODAY_COMMITS:-}" 2>/dev/null || echo "(behavior digest unavailable)")
    fi

    # Turn the facts into a status-specific instruction letter for the AI.
    if command -v coaching_build_status_prompt >/dev/null 2>&1; then
        _status_prompt=$(coaching_build_status_prompt \
            "${_status_mode:-LOCKED}" \
            "${_status_focus_text:-}" \
            "${STATUS_COACH_TODAY_COMMITS:-}" \
            "${STATUS_COACH_RECENT_PUSHES:-}" \
            "${_status_behavior_digest:-}" \
            "$CURRENT_DIR" \
            "${_status_project_context:-}" \
            "${_status_context_scope:-global}")
    else
        _status_prompt="Produce a concise mid-day GitHub-first coaching brief grounded in today's focus and current GitHub activity."
    fi

    # Ask the AI for the actual recentering message.
    if command -v coaching_generate_response >/dev/null 2>&1; then
        _status_briefing=$(coaching_generate_response "$_status_prompt" "$_status_temperature" "${_status_focus_text:-"(no focus set)"}" "${_status_mode:-LOCKED}" "$_status_combined_git" "${_status_behavior_digest:-}" "status" "${_status_project_context:-}" "${_status_context_scope:-global}" "$CURRENT_DIR")
    else
        _status_briefing="Unable to generate status coach output at this time."
    fi

    # status --coach is on-demand and intentionally not appended to coach_log,
    # so repeated mid-day recenter checks do not create noisy history.
    echo "$_status_briefing" | sed 's/^/  /'
    _COACH_CHAT_BRIEFING="$_status_briefing"
fi

# --- Display Header ---
echo ""
echo "🧭 WHERE YOU ARE:"
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
    if [[ "${STATUS_TODAY_COMMITS:-}" == "(GitHub signal unavailable)" ]]; then
        echo "  (Unable to fetch commit activity)"
    elif [ -n "${STATUS_TODAY_COMMITS:-}" ]; then
        if [ "$STATUS_TODAY_COMMITS" != "(none)" ]; then
            echo "$STATUS_TODAY_COMMITS"
        else
            echo "  (No commits yet today)"
        fi
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

# Interactive coach chat
if [[ -n "${_COACH_CHAT_BRIEFING:-}" ]] && type coach_start_chat >/dev/null 2>&1; then
    coach_start_chat "$_COACH_CHAT_BRIEFING" "status"
fi

# --- Footer ---
echo ""
echo "💡 Commands: journal | todo | startday | goodevening"
