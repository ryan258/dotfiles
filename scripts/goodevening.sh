#!/usr/bin/env bash
set -euo pipefail

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
    die "date utilities not found at $DATE_UTILS" "$EXIT_FILE_NOT_FOUND"
fi

# Initialize early so EXIT trap remains safe even if later setup fails.
GOODEVENING_ISSUES_LOG=""
cleanup_goodevening_temp_files() {
    if [ -n "${GOODEVENING_ISSUES_LOG:-}" ] && [ -f "$GOODEVENING_ISSUES_LOG" ]; then
        rm -f "$GOODEVENING_ISSUES_LOG"
    fi
}
trap cleanup_goodevening_temp_files EXIT

# --- Configuration ---
if [ -f "$CONFIG_LIB" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_LIB"
else
    die "configuration library not found at $CONFIG_LIB" "$EXIT_FILE_NOT_FOUND"
fi

# Source GitHub operations (for recent pushes + commit recap)
if [ -f "$SCRIPT_DIR/lib/github_ops.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/github_ops.sh"
fi
if [ -f "$SCRIPT_DIR/lib/coach_ops.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/coach_ops.sh"
else
    die "coach operations library not found at $SCRIPT_DIR/lib/coach_ops.sh" "$EXIT_FILE_NOT_FOUND"
fi
if [ -f "$SCRIPT_DIR/lib/coaching.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/coaching.sh"
else
    die "coaching facade not found at $SCRIPT_DIR/lib/coaching.sh" "$EXIT_FILE_NOT_FOUND"
fi

mkdir -p "$DATA_DIR"

SYSTEM_LOG_FILE="${SYSTEM_LOG_FILE:?SYSTEM_LOG_FILE is not set by config.sh}"
TODO_DONE_FILE="${DONE_FILE:?DONE_FILE is not set by config.sh}"
JOURNAL_FILE="${JOURNAL_FILE:?JOURNAL_FILE is not set by config.sh}"
FOCUS_FILE="${FOCUS_FILE:?FOCUS_FILE is not set by config.sh}"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/Projects}"

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


# 1. Determine "Today"
# If startday has not run, goodevening falls back to the system date
# (or previous day before 04:00 in interactive sessions).
# Usage: goodevening.sh [--refresh|-r] [YYYY-MM-DD]
FORCE_CURRENT_DAY=false
DATE_OVERRIDE=""

for arg in "$@"; do
    case "$arg" in
        refresh|--refresh|-r)
            FORCE_CURRENT_DAY=true
            ;;
        *)
            DATE_OVERRIDE="$arg"
            ;;
    esac
done

if [ -n "$DATE_OVERRIDE" ]; then
    TODAY="$DATE_OVERRIDE"
    echo "📅 Overriding date to: $TODAY"
else
    CURRENT_DAY_FILE="$DATA_DIR/current_day"

    if [ "$FORCE_CURRENT_DAY" = true ]; then
        TODAY=$(date +%Y-%m-%d)
        log_info "goodevening.sh: refresh requested; using system date $TODAY"
    elif [ -f "$CURRENT_DAY_FILE" ]; then
        TODAY=$(cat "$CURRENT_DAY_FILE")
        if ! [[ "$TODAY" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            TODAY=$(date +%Y-%m-%d)
            log_warn "goodevening.sh: invalid current_day marker; using system date $TODAY"
        else
            marker_mtime_epoch=$(file_mtime_epoch "$CURRENT_DAY_FILE" 2>/dev/null || echo "0")
            now_epoch=$(date +%s)
            marker_age_seconds=0
            if [[ "$marker_mtime_epoch" =~ ^[0-9]+$ ]] && [ "$marker_mtime_epoch" -gt 0 ] && [ "$now_epoch" -ge "$marker_mtime_epoch" ]; then
                marker_age_seconds=$((now_epoch - marker_mtime_epoch))
            fi

            if [ "$marker_age_seconds" -gt 86400 ]; then
                TODAY=$(date +%Y-%m-%d)
                log_warn "goodevening.sh: stale current_day marker ($marker_age_seconds seconds old); using system date $TODAY"
            fi
        fi
    else
        current_hour="$(date +%H)"
        current_hour_num=$((10#$current_hour))
        if [ -t 0 ] && [ "$current_hour_num" -lt 4 ]; then
            TODAY=$(date_shift_days -1 "%Y-%m-%d")
            log_warn "goodevening.sh: startday marker missing before 04:00; using previous day $TODAY"
        else
            TODAY=$(date +%Y-%m-%d)
            log_warn "goodevening.sh: startday marker missing; using system date $TODAY"
        fi
    fi
fi

echo "=== Evening Close-Out for $TODAY — $(date '+%Y-%m-%d %H:%M') ==="

# --- Focus ---
echo ""
echo "🎯 TODAY'S FOCUS:"
if [ -f "$FOCUS_FILE" ] && [ -s "$FOCUS_FILE" ]; then
    echo "  $(cat "$FOCUS_FILE")"
else
    echo "  (No focus set)"
fi

# 1. Show completed tasks from today
echo ""
echo "✅ COMPLETED TODAY:"
COMPLETED_TASKS=""
if [ -f "$TODO_DONE_FILE" ]; then
    COMPLETED_TASKS=$(awk -F'|' -v today="$TODAY" '$1 ~ "^"today {print}' "$TODO_DONE_FILE")
    if [ -n "$COMPLETED_TASKS" ]; then
        echo "$COMPLETED_TASKS" | sed 's/^/  • /'
    else
        echo "  (No tasks completed today)"
    fi
fi

# 2. Show today's journal entries
echo ""
echo "📝 TODAY'S JOURNAL:"
if [ -f "$JOURNAL_FILE" ]; then
    # TODAY is valid
    TODAY_JOURNAL_ENTRIES_TEXT=$(awk -F'|' -v today="$TODAY" '$1 ~ "^"today {print}' "$JOURNAL_FILE")
    if [ -n "$TODAY_JOURNAL_ENTRIES_TEXT" ]; then
        echo "$TODAY_JOURNAL_ENTRIES_TEXT" | sed 's/^/  • /'
    else
        echo "  (No journal entries for today)"
    fi
fi

# 3. Time Tracking Summary
echo ""
echo "⏱️  TIME TRACKED TODAY:"
TIME_TRACKING_LIB="$SCRIPT_DIR/lib/time_tracking.sh"
if [ -f "$TIME_TRACKING_LIB" ]; then
    # shellcheck disable=SC1090
    source "$TIME_TRACKING_LIB"
    if [ -f "$TIME_LOG" ]; then
        total_seconds=$(get_total_time_for_date "$TODAY")
        if [ "$total_seconds" -gt 0 ]; then
            echo "  Total: $(format_duration "$total_seconds")"
        else
            echo "  (No time tracked today)"
        fi
    else
        echo "  (No time log found)"
    fi
else
    echo "  (Time tracking library not found)"
fi

# --- ACTIVE PROJECTS (from GitHub) ---
echo ""
echo "🚀 RECENT PUSHES (last 7 days):"
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
    fi
else
    echo "  (GitHub operations library not loaded)"
fi

# --- COMMIT RECAP ---
echo ""
echo "🧾 COMMIT RECAP:"
TODAY_COMMITS=""
if command -v get_commit_activity_for_date >/dev/null 2>&1; then
    if command -v python3 >/dev/null 2>&1; then
        YESTERDAY=$(python3 - "$TODAY" <<'PY'
import sys
from datetime import datetime, timedelta

dt = datetime.strptime(sys.argv[1], "%Y-%m-%d") - timedelta(days=1)
print(dt.strftime("%Y-%m-%d"))
PY
)
    else
        if date -j -f "%Y-%m-%d" "$TODAY" -v-1d "+%Y-%m-%d" >/dev/null 2>&1; then
            YESTERDAY=$(date -j -f "%Y-%m-%d" "$TODAY" -v-1d "+%Y-%m-%d")
        elif command -v gdate >/dev/null 2>&1; then
            YESTERDAY=$(gdate -d "$TODAY -1 day" "+%Y-%m-%d")
        else
            YESTERDAY=$(date -d "$TODAY -1 day" "+%Y-%m-%d")
        fi
    fi
    echo "  Yesterday ($YESTERDAY):"
    if ! get_commit_activity_for_date "$YESTERDAY"; then
        echo "  (Unable to fetch commit activity. Check your token or network.)"
    fi
    echo "  Today ($TODAY):"
    if TODAY_COMMITS=$(get_commit_activity_for_date "$TODAY" 2>/dev/null); then
        if [ -n "$TODAY_COMMITS" ]; then
            echo "$TODAY_COMMITS"
        else
            echo "  (No commits yet today)"
        fi
    else
        echo "  (Unable to fetch commit activity. Check your token or network.)"
    fi
else
    echo "  (GitHub operations library not loaded)"
fi

# --- Gamify Progress ---
echo ""
echo "🌟 TODAY'S WINS:"
TASKS_COMPLETED=0
JOURNAL_ENTRY_COUNT=0
if [ -f "$TODO_DONE_FILE" ]; then
    TASKS_COMPLETED=$(awk -F'|' -v today="$TODAY" '$1 ~ "^"today {count++} END {print count+0}' "$TODO_DONE_FILE")
fi
if [ -f "$JOURNAL_FILE" ]; then
    JOURNAL_ENTRY_COUNT=$(awk -F'|' -v today="$TODAY" '$1 ~ "^"today {count++} END {print count+0}' "$JOURNAL_FILE")
fi

if [ "$TASKS_COMPLETED" -gt 0 ]; then
    echo "  🎉 Win: You completed $TASKS_COMPLETED task(s) today. Progress is progress."
fi

if [ "$JOURNAL_ENTRY_COUNT" -gt 0 ]; then
    echo "  🧠 Win: You logged $JOURNAL_ENTRY_COUNT entries. Context captured."
fi

if [ "$TASKS_COMPLETED" -eq 0 ] && [ "$JOURNAL_ENTRY_COUNT" -eq 0 ]; then
    echo "  🧘 Today was a rest day. Logging off is a valid and productive choice."
fi

# 3. Automation Safety Nets - Check projects for potential issues
echo ""
echo "🚀 PROJECT SAFETY CHECK:"
if [ -d "$PROJECTS_DIR" ]; then
    found_issues=false

    # Create a temp file to track issues found in subshells
    GOODEVENING_ISSUES_LOG=$(create_temp_file "goodevening-issues")
    
    while IFS= read -r gitdir; do
        proj_dir=$(dirname "$gitdir")
        proj_name=$(basename "$proj_dir")

        (
            cd "$proj_dir" || exit
            
            issue_found=false

            # Check for uncommitted changes
            if git status --porcelain | grep -q .; then
                change_count=$(git status --porcelain | wc -l | tr -d ' ')
                echo "  ⚠️  $proj_name: $change_count uncommitted changes"
                issue_found=true

                # Check for large diffs
                additions=$(git diff --stat | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
                deletions=$(git diff --stat | tail -1 | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
                total_changes=$((additions + deletions))

                if [ "$total_changes" -gt 100 ]; then
                    echo "      └─ Large diff: +$additions/-$deletions lines"
                fi
            fi

            # Check for lingering non-default branches
            current_branch=$(git branch --show-current)
            if ! git branch --show-current >/dev/null 2>&1; then
                echo "      └─ Could not determine current branch. Is this a valid git repository?"
            else
                default_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@' || echo "main")

                if [ "$current_branch" != "$default_branch" ] && [ "$current_branch" != "main" ] && [ "$current_branch" != "master" ]; then
                    # Check how old this branch is
                    branch_age_days=$(( ( $(date +%s) - $(git log -1 --format=%ct "$current_branch" || echo 0) ) / 86400 ))

                    if [ "$branch_age_days" -gt 7 ]; then
                        echo "  ⚠️  $proj_name: On branch '$current_branch' (${branch_age_days} days old)"
                        issue_found=true

                        # Check if branch is pushed to remote
                        if remote_check=$(git ls-remote --heads origin "$current_branch" 2>&1); then
                            if ! echo "$remote_check" | grep -q .; then
                                echo "      └─ Branch not pushed to remote"
                            fi
                        else
                            echo "      └─ Failed to check remote status: $remote_check"
                        fi
                    fi
                fi

                # Check for unpushed commits on default branch
                if [ "$current_branch" = "$default_branch" ] || [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
                    # Check if upstream branch exists (expected to fail for local-only branches)
                    if git rev-parse @{u} >/dev/null 2>&1; then
                        # Upstream exists, check for unpushed commits
                        if ! unpushed=$(git rev-list @{u}..HEAD --count 2>&1); then
                            echo "  ⚠️  $proj_name: Failed to check unpushed commits: $unpushed"
                            issue_found=true
                        elif [ "$unpushed" -gt 0 ]; then
                            echo "  📤 $proj_name: $unpushed unpushed commit(s) on $current_branch"
                            issue_found=true
                        fi
                    fi
                fi
            fi
            
            if [ "$issue_found" = true ]; then
                echo "issue" >> "$GOODEVENING_ISSUES_LOG"
            fi
        )
    done < <(find "$PROJECTS_DIR" -maxdepth 2 -type d -name ".git")

    if [ -s "$GOODEVENING_ISSUES_LOG" ]; then
        found_issues=true
    fi
    rm -f "$GOODEVENING_ISSUES_LOG"
    GOODEVENING_ISSUES_LOG=""

    if [ "$found_issues" = false ]; then
        echo "  ✅ All projects clean (no uncommitted changes, stale branches, or unpushed commits)"
    fi
else
    echo "  (Projects directory not found)"
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


# 7. Clear completed tasks older than 7 days
echo ""
echo "🧹 Tidying up old completed tasks..."
if [ -f "$TODO_DONE_FILE" ]; then
    CUTOFF_DATE_STR=$(date_shift_days -7 "%Y-%m-%d")
    tasks_to_remove=$(awk -F'|' -v cutoff="$CUTOFF_DATE_STR" 'NF>=2 { date_str = substr($1, 1, 10); if (date_str < cutoff) { count++ } } END { print count+0 }' "$TODO_DONE_FILE")
    echo "$(date): goodevening.sh - Cleaned $tasks_to_remove old tasks." >> "$SYSTEM_LOG_FILE"
    awk -F'|' -v cutoff="$CUTOFF_DATE_STR" '
        NF >= 2 {
            date_str = substr($1, 1, 10)
            if (date_str >= cutoff) {
                print
            }
            next
        }
        { print }
    ' "$TODO_DONE_FILE" > "${TODO_DONE_FILE}.tmp" && mv "${TODO_DONE_FILE}.tmp" "$TODO_DONE_FILE"
    chmod 600 "$TODO_DONE_FILE"
    echo "  (Old completed tasks removed)"
fi

# 8. Data Validation
echo ""
echo "🛡️  Validating data integrity..."
if bash "$(dirname "$0")/data_validate.sh"; then
    echo "  ✅ Data validation passed."
    # 9. Backup of dotfiles data
    echo "$(date): goodevening.sh - Backing up dotfiles data." >> "$SYSTEM_LOG_FILE"
    if ! backup_output=$(/bin/bash "$(dirname "$0")/backup_data.sh" 2>&1); then
        echo "  ⚠️  WARNING: Backup failed: $backup_output"
        echo "$(date): goodevening.sh - Backup failed: $backup_output" >> "$SYSTEM_LOG_FILE"
    fi
else
    echo "  ❌ ERROR: Data validation failed. Skipping backup."
fi

# --- AI REFLECTION (Optional) ---
if [ "${AI_REFLECTION_ENABLED:-false}" = "true" ]; then
    echo ""
    echo "🤖 AI REFLECTION:"

    # Gather today's data
    # TODAY is already set globally (handling overrides)
    COMPLETED_TASKS_CONTEXT="${COMPLETED_TASKS:-}"
    if [ -z "$COMPLETED_TASKS_CONTEXT" ] && [ -f "$TODO_DONE_FILE" ]; then
        COMPLETED_TASKS_CONTEXT=$(awk -F'|' -v today="$TODAY" '$1 ~ "^"today {print}' "$TODO_DONE_FILE" 2>/dev/null || echo "")
    fi
    TODAY_JOURNAL=$(awk -F'|' -v today="$TODAY" '$1 ~ "^"today {print}' "$JOURNAL_FILE" 2>/dev/null || echo "")
    FOCUS_CONTEXT=""
    if [ -f "$FOCUS_FILE" ] && [ -s "$FOCUS_FILE" ]; then
        FOCUS_CONTEXT=$(cat "$FOCUS_FILE")
    fi
    COACH_TACTICAL_DAYS="${AI_COACH_TACTICAL_DAYS:-7}"
    COACH_PATTERN_DAYS="${AI_COACH_PATTERN_DAYS:-30}"
    COACH_MODE="${AI_COACH_MODE_DEFAULT:-LOCKED}"
    COACH_TACTICAL_METRICS=""
    COACH_PATTERN_METRICS=""
    COACH_DATA_QUALITY_FLAGS=""
    COACH_BEHAVIOR_DIGEST="(behavior digest unavailable)"
    COACH_TEMPERATURE="${AI_BRIEFING_TEMPERATURE:-0.25}"

    if command -v coaching_get_mode_for_date >/dev/null 2>&1; then
        COACH_INTERACTIVE="false"
        if [ -t 0 ]; then
            COACH_INTERACTIVE="true"
        fi
        COACH_MODE=$(coaching_get_mode_for_date "$TODAY" "$COACH_INTERACTIVE" 2>/dev/null || echo "${AI_COACH_MODE_DEFAULT:-LOCKED}")
    fi

    if command -v coaching_collect_tactical_metrics >/dev/null 2>&1; then
        COACH_TACTICAL_METRICS=$(coaching_collect_tactical_metrics "$TODAY" "$COACH_TACTICAL_DAYS" "${RECENT_PUSHES:-}" "${TODAY_COMMITS:-}" 2>/dev/null || true)
    fi
    if command -v coaching_collect_pattern_metrics >/dev/null 2>&1; then
        COACH_PATTERN_METRICS=$(coaching_collect_pattern_metrics "$TODAY" "$COACH_PATTERN_DAYS" 2>/dev/null || true)
    fi
    if command -v coaching_collect_data_quality_flags >/dev/null 2>&1; then
        COACH_DATA_QUALITY_FLAGS=$(coaching_collect_data_quality_flags 2>/dev/null || true)
    fi
    if command -v coaching_build_behavior_digest >/dev/null 2>&1; then
        COACH_BEHAVIOR_DIGEST=$(coaching_build_behavior_digest "$TODAY" "$COACH_TACTICAL_DAYS" "$COACH_PATTERN_DAYS" 2>/dev/null || echo "(behavior digest unavailable)")
    fi

    if command -v coaching_build_goodevening_prompt >/dev/null 2>&1; then
        REFLECTION_PROMPT="$(coaching_build_goodevening_prompt \
            "${COACH_MODE:-LOCKED}" \
            "${FOCUS_CONTEXT:-}" \
            "${TODAY_COMMITS:-}" \
            "${RECENT_PUSHES:-}" \
            "${COMPLETED_TASKS_CONTEXT:-}" \
            "${TODAY_JOURNAL:-}" \
            "${COACH_BEHAVIOR_DIGEST:-}")"
    else
        REFLECTION_PROMPT="Produce a reflective coaching summary grounded in today's completed tasks, journal entries, and focus."
    fi
    REFLECTION=""
    REFLECTION_REASON="ai-error"

    if command -v dhp-strategy.sh >/dev/null 2>&1; then
        if command -v coaching_strategy_with_retry >/dev/null 2>&1; then
            if REFLECTION=$(coaching_strategy_with_retry "$REFLECTION_PROMPT" "$COACH_TEMPERATURE" "${AI_COACH_REQUEST_TIMEOUT_SECONDS:-35}" "${AI_COACH_RETRY_TIMEOUT_SECONDS:-90}" 2>/dev/null); then
                REFLECTION_REASON=""
            else
                strategy_status=$?
                if [ "$strategy_status" -eq 124 ]; then
                    REFLECTION_REASON="timeout"
                else
                    REFLECTION_REASON="error"
                fi
            fi
        else
            if REFLECTION=$(printf '%s' "$REFLECTION_PROMPT" | dhp-strategy.sh --temperature "$COACH_TEMPERATURE" 2>/dev/null); then
                REFLECTION_REASON=""
            else
                REFLECTION_REASON="error"
            fi
        fi
    else
        REFLECTION_REASON="dispatcher-missing"
    fi

    if [ -z "$REFLECTION" ]; then
        if command -v coaching_goodevening_fallback_output >/dev/null 2>&1; then
            REFLECTION=$(coaching_goodevening_fallback_output "${FOCUS_CONTEXT:-"(no focus set)"}" "$COACH_MODE" "${REFLECTION_REASON:-unavailable}")
        else
            REFLECTION="Unable to generate AI reflection at this time."
        fi
    fi

    echo "$REFLECTION" | sed 's/^/  /'

    if command -v coaching_append_log >/dev/null 2>&1; then
        COACH_METRICS_PAYLOAD="tactical:$(printf '%s' "$COACH_TACTICAL_METRICS" | tr '\n' ';') pattern:$(printf '%s' "$COACH_PATTERN_METRICS" | tr '\n' ';') quality:$(printf '%s' "$COACH_DATA_QUALITY_FLAGS" | tr '\n' ';')"
        coaching_append_log "GOODEVENING" "$TODAY" "$COACH_MODE" "${FOCUS_CONTEXT:-"(no focus set)"}" "$COACH_METRICS_PAYLOAD" "$REFLECTION" || true
    fi
fi

echo ""
echo "Evening wrap-up complete. Have a great night!"
