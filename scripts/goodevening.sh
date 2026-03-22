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
for coach_module in coach_metrics.sh coach_prompts.sh coach_scoring.sh; do
    if [ -f "$SCRIPT_DIR/lib/$coach_module" ]; then
        # shellcheck disable=SC1090
        source "$SCRIPT_DIR/lib/$coach_module"
    else
        die "coach module not found at $SCRIPT_DIR/lib/$coach_module" "$EXIT_FILE_NOT_FOUND"
    fi
done
if [ -f "$SCRIPT_DIR/lib/coaching.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/coaching.sh"
else
    die "coaching facade not found at $SCRIPT_DIR/lib/coaching.sh" "$EXIT_FILE_NOT_FOUND"
fi
if [ -f "$SCRIPT_DIR/lib/coach_chat.sh" ]; then
    source "$SCRIPT_DIR/lib/coach_chat.sh"
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
    if ! validate_date_ymd "$TODAY" "override date" >/dev/null 2>&1; then
        die "Invalid date override '$TODAY' (expected YYYY-MM-DD)." "$EXIT_INVALID_ARGS"
    fi
    echo "📅 Overriding date to: $TODAY"
else
    CURRENT_DAY_FILE="$DATA_DIR/current_day"

    if [ "$FORCE_CURRENT_DAY" = true ]; then
        TODAY=$(date_today)
        log_info "goodevening.sh: refresh requested; using system date $TODAY"
    elif [ -f "$CURRENT_DAY_FILE" ]; then
        TODAY=$(cat "$CURRENT_DAY_FILE")
        if ! validate_date_ymd "$TODAY" "current_day marker" >/dev/null 2>&1; then
            TODAY=$(date_today)
            log_warn "goodevening.sh: invalid current_day marker; using system date $TODAY"
        else
            marker_mtime_epoch=$(file_mtime_epoch "$CURRENT_DAY_FILE" 2>/dev/null || echo "0")
            now_epoch=$(date_epoch_now)
            marker_age_seconds=0
            if validate_numeric "$marker_mtime_epoch" "marker mtime epoch" >/dev/null 2>&1 && [ "$marker_mtime_epoch" -gt 0 ] && [ "$now_epoch" -ge "$marker_mtime_epoch" ]; then
                marker_age_seconds=$((now_epoch - marker_mtime_epoch))
            fi

            if [ "$marker_age_seconds" -gt 86400 ]; then
                TODAY=$(date_today)
                log_warn "goodevening.sh: stale current_day marker ($marker_age_seconds seconds old); using system date $TODAY"
            fi
        fi
    else
        current_hour="$(date_hour_24)"
        current_hour_num=$((10#$current_hour))
        if [ -t 0 ] && [ "$current_hour_num" -lt 4 ]; then
            TODAY=$(date_shift_days -1 "%Y-%m-%d")
            log_warn "goodevening.sh: startday marker missing before 04:00; using previous day $TODAY"
        else
            TODAY=$(date_today)
            log_warn "goodevening.sh: startday marker missing; using system date $TODAY"
        fi
    fi
fi

echo "=== Evening Close-Out for $TODAY — $(date_now '%Y-%m-%d %H:%M') ==="

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
        if command -v time_tracking_supports_assoc_arrays >/dev/null 2>&1 && ! time_tracking_supports_assoc_arrays; then
            echo "  (Time tracking requires Bash 4+; current shell: ${BASH_VERSION:-unknown}. Ensure /usr/bin/env bash resolves to a newer Bash.)"
        else
            total_seconds=$(get_total_time_for_date "$TODAY")
            if [ "$total_seconds" -gt 0 ]; then
                echo "  Total: $(format_duration "$total_seconds")"
            else
                echo "  (No time tracked today)"
            fi
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
        RECENT_PUSHES="(GitHub signal unavailable)"
    fi
else
    echo "  (GitHub operations library not loaded)"
    RECENT_PUSHES="(GitHub signal unavailable)"
fi

# --- COMMIT RECAP ---
echo ""
echo "🧾 COMMIT RECAP:"
TODAY_COMMITS=""
if command -v get_commit_activity_for_date >/dev/null 2>&1; then
    YESTERDAY=$(date_shift_from "$TODAY" -1 "%Y-%m-%d")
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
        TODAY_COMMITS="(GitHub signal unavailable)"
    fi
else
    echo "  (GitHub operations library not loaded)"
    TODAY_COMMITS="(GitHub signal unavailable)"
fi

# --- Gamify Progress ---
echo ""
echo "🌟 TODAY'S WINS:"
TASKS_COMPLETED=0
JOURNAL_ENTRY_COUNT=0
_GE_COMMIT_COUNT=0
if [ -f "$TODO_DONE_FILE" ]; then
    TASKS_COMPLETED=$(awk -F'|' -v today="$TODAY" '$1 ~ "^"today {count++} END {print count+0}' "$TODO_DONE_FILE")
fi
if [ -f "$JOURNAL_FILE" ]; then
    JOURNAL_ENTRY_COUNT=$(awk -F'|' -v today="$TODAY" '$1 ~ "^"today {count++} END {print count+0}' "$JOURNAL_FILE")
fi
# Count commits across repos as a win signal
if command -v git >/dev/null 2>&1; then
    for _ge_repo in "$HOME/dotfiles" "${PROJECTS_DIR:-$HOME/Projects}"/*; do
        if [ -d "$_ge_repo/.git" ]; then
            _ge_repo_commits=$(git -C "$_ge_repo" log --oneline --after="$TODAY 00:00:00" --before="$TODAY 23:59:59" --all 2>/dev/null | wc -l | tr -d ' ')
            _GE_COMMIT_COUNT=$((_GE_COMMIT_COUNT + _ge_repo_commits))
        fi
    done
fi

if [ "$TASKS_COMPLETED" -gt 0 ]; then
    echo "  🎉 Win: You completed $TASKS_COMPLETED task(s) today. Progress is progress."
fi

if [ "$JOURNAL_ENTRY_COUNT" -gt 0 ]; then
    echo "  🧠 Win: You logged $JOURNAL_ENTRY_COUNT entries. Context captured."
fi

if [ "$_GE_COMMIT_COUNT" -gt 0 ] && [ "$TASKS_COMPLETED" -eq 0 ]; then
    echo "  💻 Win: You made $_GE_COMMIT_COUNT commit(s) today. Code shipped even without logged tasks."
fi

if [ "$TASKS_COMPLETED" -eq 0 ] && [ "$JOURNAL_ENTRY_COUNT" -eq 0 ] && [ "$_GE_COMMIT_COUNT" -eq 0 ]; then
    # Smarter rest day detection: distinguish intentional rest from health crashes
    _ge_had_low_energy=false
    _ge_had_high_fog=false
    _ge_spoons_exhausted=false
    _ge_had_health_entries=false
    _ge_focus_completed=false
    _ge_low_energy_threshold="${COACH_LOW_ENERGY_THRESHOLD:-4}"
    _ge_high_fog_threshold="${COACH_HIGH_FOG_THRESHOLD:-6}"

    # Check health readings
    if [ -f "${HEALTH_FILE:-}" ]; then
        _ge_low_energy=$(awk -F'|' -v day="$TODAY" -v threshold="$_ge_low_energy_threshold" '
            $1 == "ENERGY" && substr($2, 1, 10) == day && $3 ~ /^[0-9]+$/ && $3 <= threshold { found=1 }
            END { print found+0 }
        ' "$HEALTH_FILE")
        _ge_high_fog=$(awk -F'|' -v day="$TODAY" -v threshold="$_ge_high_fog_threshold" '
            $1 == "FOG" && substr($2, 1, 10) == day && $3 ~ /^[0-9]+$/ && $3 >= threshold { found=1 }
            END { print found+0 }
        ' "$HEALTH_FILE")
        _ge_any_health=$(awk -F'|' -v day="$TODAY" '
            substr($2, 1, 10) == day { found=1 }
            END { print found+0 }
        ' "$HEALTH_FILE")
        [ "$_ge_low_energy" -eq 1 ] && _ge_had_low_energy=true
        [ "$_ge_high_fog" -eq 1 ] && _ge_had_high_fog=true
        [ "$_ge_any_health" -eq 1 ] && _ge_had_health_entries=true
    fi

    # Check spoon exhaustion
    if [ -f "${SPOON_LOG:-}" ]; then
        _ge_budget=$(grep "^BUDGET|$TODAY" "$SPOON_LOG" 2>/dev/null | tail -1 | cut -d'|' -f3 || true)
        _ge_last_remaining=$(grep "^SPEND|$TODAY" "$SPOON_LOG" 2>/dev/null | tail -1 | cut -d'|' -f6 || true)
        if [ -n "$_ge_budget" ] && [ -n "$_ge_last_remaining" ] && [ "$_ge_budget" -gt 0 ] 2>/dev/null; then
            _ge_pct_left=$(awk -v r="$_ge_last_remaining" -v b="$_ge_budget" 'BEGIN { printf "%d", (r/b)*100 }')
            [ "$_ge_pct_left" -le 20 ] && _ge_spoons_exhausted=true
        fi
    fi

    # Check if focus was completed
    if [ -f "${FOCUS_HISTORY_FILE:-}" ]; then
        if grep -q "^$TODAY|.*Completed" "$FOCUS_HISTORY_FILE" 2>/dev/null; then
            _ge_focus_completed=true
        fi
    fi

    if [ "$_ge_had_low_energy" = true ] || [ "$_ge_had_high_fog" = true ] || [ "$_ge_spoons_exhausted" = true ]; then
        echo "  💪 Tough day. Your body needed rest — that's not failure, it's management."
    elif [ "$_ge_focus_completed" = true ]; then
        echo "  ✅ Focus completed! Tasks may not be captured but the goal was met."
    elif [ "$_ge_had_health_entries" = true ]; then
        echo "  🧘 Quiet day with some health tracking. Rest is productive."
    else
        echo "  🧘 Today was a rest day. Logging off is a valid and productive choice."
    fi
fi

# 3. Automation Safety Nets - Check projects for potential issues
echo ""
echo "🚀 PROJECT SAFETY CHECK:"
if [ -d "$PROJECTS_DIR" ]; then
    found_issues=false

    project_has_safety_issue() {
        local proj_dir="$1"
        local proj_name="$2"
        local issue_found=false
        local current_branch=""
        local default_branch="main"

        # Check for uncommitted changes
        if git -C "$proj_dir" status --porcelain 2>/dev/null | grep -q .; then
            local change_count
            local additions
            local deletions
            local total_changes
            change_count=$(git -C "$proj_dir" status --porcelain | wc -l | tr -d ' ')
            echo "  ⚠️  $proj_name: $change_count uncommitted changes"
            issue_found=true

            additions=$(git -C "$proj_dir" diff --stat | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
            deletions=$(git -C "$proj_dir" diff --stat | tail -1 | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
            total_changes=$((additions + deletions))
            if [ "$total_changes" -gt 100 ]; then
                echo "      └─ Large diff: +$additions/-$deletions lines"
            fi
        fi

        current_branch=$(git -C "$proj_dir" branch --show-current 2>/dev/null || true)
        if [ -z "$current_branch" ]; then
            echo "      └─ Could not determine current branch. Is this a valid git repository?"
        else
            default_branch=$(git -C "$proj_dir" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

            if [ "$current_branch" != "$default_branch" ] && [ "$current_branch" != "main" ] && [ "$current_branch" != "master" ]; then
                local branch_commit_epoch
                local branch_age_days
                branch_commit_epoch=$(git -C "$proj_dir" log -1 --format=%ct "$current_branch" 2>/dev/null || echo "0")
                branch_age_days=$(( ( $(date_epoch_now) - branch_commit_epoch ) / 86400 ))
                if [ "$branch_age_days" -gt 7 ]; then
                    local remote_check
                    echo "  ⚠️  $proj_name: On branch '$current_branch' (${branch_age_days} days old)"
                    issue_found=true
                    if remote_check=$(git -C "$proj_dir" ls-remote --heads origin "$current_branch" 2>&1); then
                        if ! echo "$remote_check" | grep -q .; then
                            echo "      └─ Branch not pushed to remote"
                        fi
                    else
                        echo "      └─ Failed to check remote status: $remote_check"
                    fi
                fi
            fi

            if [ "$current_branch" = "$default_branch" ] || [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
                if git -C "$proj_dir" rev-parse '@{u}' >/dev/null 2>&1; then
                    local unpushed
                    if ! unpushed=$(git -C "$proj_dir" rev-list '@{u}..HEAD' --count 2>&1); then
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
            return 0
        fi
        return 1
    }

    _ge_scan_limit="${GOODEVENING_PROJECT_SCAN_LIMIT:-20}"
    if ! [[ "$_ge_scan_limit" =~ ^[0-9]+$ ]] || [ "$_ge_scan_limit" -lt 1 ]; then
        _ge_scan_limit=20
    fi
    _ge_scan_jobs="${GOODEVENING_PROJECT_SCAN_JOBS:-8}"
    if ! [[ "$_ge_scan_jobs" =~ ^[0-9]+$ ]] || [ "$_ge_scan_jobs" -lt 1 ]; then
        _ge_scan_jobs=8
    fi

    job_count=0
    tmp_results=$(mktemp -d)
    while IFS= read -r gitdir; do
        (
            proj_dir=$(dirname "$gitdir")
            proj_name=$(basename "$proj_dir")
            if project_has_safety_issue "$proj_dir" "$proj_name" > "$tmp_results/$proj_name"; then
                mv "$tmp_results/$proj_name" "$tmp_results/${proj_name}.issue"
            else
                rm -f "$tmp_results/$proj_name"
            fi
        ) &
        job_count=$((job_count + 1))
        if [ "$job_count" -ge "$_ge_scan_jobs" ]; then
            wait
            job_count=0
        fi
    done < <(find "$PROJECTS_DIR" -maxdepth 2 -type d -name ".git" | head -n "$_ge_scan_limit")

    wait

    for issue_file in "$tmp_results"/*.issue; do
        if [ -f "$issue_file" ]; then
            found_issues=true
            cat "$issue_file"
        fi
    done
    rm -rf "$tmp_results"

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
    CUTOFF_DATE_STR=$(date_shift_days "-${STALE_TASK_DAYS}" "%Y-%m-%d")
    tasks_to_remove=$(awk -F'|' -v cutoff="$CUTOFF_DATE_STR" 'NF>=2 { date_str = substr($1, 1, 10); if (date_str < cutoff) { count++ } } END { print count+0 }' "$TODO_DONE_FILE")
    echo "$(date_now): goodevening.sh - Cleaned $tasks_to_remove old tasks." >> "$SYSTEM_LOG_FILE"
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
    echo "$(date_now): goodevening.sh - Backing up dotfiles data." >> "$SYSTEM_LOG_FILE"
if ! backup_output=$("$SCRIPT_DIR/backup_data.sh" 2>&1); then
        echo "  ⚠️  WARNING: Backup failed: $backup_output"
        echo "$(date_now): goodevening.sh - Backup failed: $backup_output" >> "$SYSTEM_LOG_FILE"
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
        COACH_BEHAVIOR_DIGEST=$(coaching_build_behavior_digest "$TODAY" "$COACH_TACTICAL_DAYS" "$COACH_PATTERN_DAYS" "${RECENT_PUSHES:-}" "${TODAY_COMMITS:-}" 2>/dev/null || echo "(behavior digest unavailable)")
    fi

    if command -v coaching_build_goodevening_prompt >/dev/null 2>&1; then
        REFLECTION_PROMPT="$(coaching_build_goodevening_prompt \
            "${COACH_MODE:-LOCKED}" \
            "${FOCUS_CONTEXT:-}" \
            "${TODAY_COMMITS:-}" \
            "${RECENT_PUSHES:-}" \
            "${COACH_BEHAVIOR_DIGEST:-}")"
    else
        REFLECTION_PROMPT="Produce a reflective coaching summary grounded in today's focus and GitHub evidence."
    fi
    REFLECTION=""
    REFLECTION_REASON="ai-error"
    REFLECTION_REASON_DETAIL=""

    COACH_DISPATCHER=""
    if command -v coaching_strategy_dispatcher_name >/dev/null 2>&1; then
        COACH_DISPATCHER=$(coaching_strategy_dispatcher_name 2>/dev/null || true)
    fi

    if [ -n "$COACH_DISPATCHER" ]; then
        if command -v coaching_strategy_with_retry >/dev/null 2>&1; then
            if REFLECTION=$(coaching_strategy_with_retry "$REFLECTION_PROMPT" "$COACH_TEMPERATURE" "${AI_COACH_REQUEST_TIMEOUT_SECONDS:-35}" "${AI_COACH_RETRY_TIMEOUT_SECONDS:-90}"); then
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
            if REFLECTION=$(printf '%s' "$REFLECTION_PROMPT" | "$COACH_DISPATCHER" --temperature "$COACH_TEMPERATURE"); then
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
            REFLECTION=$(coaching_goodevening_fallback_output "${FOCUS_CONTEXT:-"(no focus set)"}" "$COACH_MODE" "${REFLECTION_REASON:-unavailable}" "${COACH_BEHAVIOR_DIGEST:-}" "${TODAY_COMMITS:-}" "${REFLECTION_REASON_DETAIL:-}")
        else
            REFLECTION="Unable to generate AI reflection at this time."
        fi
    elif [ -z "$REFLECTION_REASON" ] && [ "${AI_COACH_EVIDENCE_CHECK_ENABLED:-true}" = "true" ] && command -v coaching_goodevening_response_is_grounded >/dev/null 2>&1; then
        if ! coaching_goodevening_response_is_grounded "$REFLECTION" "${FOCUS_CONTEXT:-"(no focus set)"}" "$(printf '%s\n%s\n' "${TODAY_COMMITS:-}" "${RECENT_PUSHES:-}")" "$COACH_MODE"; then
            if command -v coach_grounding_failure_message >/dev/null 2>&1; then
                REFLECTION_REASON_DETAIL=$(coach_grounding_failure_message)
            elif [[ -n "${COACH_GROUNDING_FAILURE_REASON:-}" ]]; then
                REFLECTION_REASON_DETAIL="${COACH_GROUNDING_FAILURE_REASON:-}"
            fi
            REFLECTION_REASON="ungrounded-reflection"
            if [[ -n "${REFLECTION_REASON_DETAIL:-}" ]]; then
                printf 'AI coach: rejected reflection (%s).\n' "$REFLECTION_REASON_DETAIL" >&2
            else
                echo "AI coach: rejected reflection (ungrounded-reflection)." >&2
            fi
            if command -v coaching_goodevening_fallback_output >/dev/null 2>&1; then
                REFLECTION=$(coaching_goodevening_fallback_output "${FOCUS_CONTEXT:-"(no focus set)"}" "$COACH_MODE" "${REFLECTION_REASON:-unavailable}" "${COACH_BEHAVIOR_DIGEST:-}" "${TODAY_COMMITS:-}" "${REFLECTION_REASON_DETAIL:-}")
            fi
        fi
    fi

    if command -v coaching_sanitize_goodevening_blindspots >/dev/null 2>&1; then
        REFLECTION=$(coaching_sanitize_goodevening_blindspots \
            "$REFLECTION" \
            "${FOCUS_CONTEXT:-"(no focus set)"}" \
            "${COACH_BEHAVIOR_DIGEST:-}" \
            "$(printf '%s\n%s\n' "${TODAY_COMMITS:-}" "${RECENT_PUSHES:-}")")
    fi

    echo "$REFLECTION" | sed 's/^/  /'
    _COACH_CHAT_BRIEFING="$REFLECTION"

    # Signal metadata: summarize confidence and why evidence is sparse.
    _ge_present=0
    _ge_reasons=()
    if [ -n "${FOCUS_CONTEXT:-}" ]; then
        _ge_present=$((_ge_present + 1))
    else
        _ge_reasons+=("no focus")
    fi
    if [[ "${TODAY_COMMITS:-}" == *"GitHub signal unavailable"* ]] || [[ "${RECENT_PUSHES:-}" == *"GitHub signal unavailable"* ]]; then
        _ge_reasons+=("github signal unavailable")
    elif { [ -n "${TODAY_COMMITS:-}" ] && [ "$TODAY_COMMITS" != "(none)" ]; } || { [ -n "${RECENT_PUSHES:-}" ] && [ "$RECENT_PUSHES" != "(none)" ]; }; then
        _ge_present=$((_ge_present + 1))
    else
        _ge_reasons+=("no non-fork github activity")
    fi
    _ge_health_count=0
    if [ -f "${HEALTH_FILE:-}" ]; then
        _ge_health_count=$(awk -F'|' -v day="$TODAY" 'substr($2, 1, 10) == day {count++} END {print count+0}' "$HEALTH_FILE")
    fi
    if [ "${_ge_health_count:-0}" -gt 0 ]; then
        _ge_present=$((_ge_present + 1))
    else
        _ge_reasons+=("no health logs")
    fi
    if [ "${COACH_BEHAVIOR_DIGEST:-}" != "(behavior digest unavailable)" ]; then
        _ge_present=$((_ge_present + 1))
    else
        _ge_reasons+=("no behavior digest")
    fi

    _ge_signal_confidence="LOW"
    if [ "${_ge_present:-0}" -ge 4 ] && [ "${#_ge_reasons[@]}" -eq 0 ]; then
        _ge_signal_confidence="HIGH"
    elif [ "${_ge_present:-0}" -ge 3 ]; then
        _ge_signal_confidence="MEDIUM"
    fi
    if [ "${#_ge_reasons[@]}" -eq 0 ]; then
        _ge_signal_reason_text="all primary sources available"
    else
        _ge_signal_reason_text=$(printf '%s' "${_ge_reasons[0]}")
        for _reason in "${_ge_reasons[@]:1}"; do
            _ge_signal_reason_text="${_ge_signal_reason_text}, ${_reason}"
        done
    fi
    printf '  (Signal: %s - %s)\n' "$_ge_signal_confidence" "$_ge_signal_reason_text"

    echo "$REFLECTION" > "$DATA_DIR/tomorrow_launchpad"

    if command -v coaching_append_log >/dev/null 2>&1; then
        COACH_METRICS_PAYLOAD="tactical:$(printf '%s' "$COACH_TACTICAL_METRICS" | tr '\n' ';') pattern:$(printf '%s' "$COACH_PATTERN_METRICS" | tr '\n' ';') quality:$(printf '%s' "$COACH_DATA_QUALITY_FLAGS" | tr '\n' ';')"
        coaching_append_log "GOODEVENING" "$TODAY" "$COACH_MODE" "${FOCUS_CONTEXT:-"(no focus set)"}" "$COACH_METRICS_PAYLOAD" "$REFLECTION" || true
    fi
fi

# Interactive coach chat
if [[ -n "${_COACH_CHAT_BRIEFING:-}" ]] && type coach_start_chat >/dev/null 2>&1; then
    coach_start_chat "$_COACH_CHAT_BRIEFING" "goodevening"
fi

echo ""
echo "Evening wrap-up complete. Have a great night!"
