#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/loader.sh" || exit 1

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


# Determine the session date from startday marker, override, or system clock.
# Usage: determine_session_date [--force-current] [date_override]
# Prints the resolved YYYY-MM-DD date to stdout.
determine_session_date() {
    local force_current="${1:-false}"
    local date_override="${2:-}"
    local current_day_file="$DATA_DIR/current_day"

    # Explicit override takes priority
    if [ -n "$date_override" ]; then
        if ! validate_date_ymd "$date_override" "override date" >/dev/null 2>&1; then
            die "Invalid date override '$date_override' (expected YYYY-MM-DD)." "$EXIT_INVALID_ARGS"
        fi
        echo "📅 Overriding date to: $date_override" >&2
        printf '%s' "$date_override"
        return 0
    fi

    # Refresh flag: use system date
    if [ "$force_current" = true ]; then
        log_info "goodevening.sh: refresh requested; using system date $(date_today)"
        date_today
        return 0
    fi

    # Read startday marker if available
    if [ -f "$current_day_file" ]; then
        local marker_date
        marker_date=$(cat "$current_day_file")

        if ! validate_date_ymd "$marker_date" "current_day marker" >/dev/null 2>&1; then
            log_warn "goodevening.sh: invalid current_day marker; using system date $(date_today)"
            date_today
            return 0
        fi

        # Check for stale marker (> 24 hours old)
        local marker_mtime marker_age_seconds now_epoch
        marker_mtime=$(file_mtime_epoch "$current_day_file" 2>/dev/null || echo "0")
        now_epoch=$(date_epoch_now)
        marker_age_seconds=0
        if validate_numeric "$marker_mtime" "marker mtime epoch" >/dev/null 2>&1 && [ "$marker_mtime" -gt 0 ] && [ "$now_epoch" -ge "$marker_mtime" ]; then
            marker_age_seconds=$((now_epoch - marker_mtime))
        fi

        if [ "$marker_age_seconds" -gt 86400 ]; then
            log_warn "goodevening.sh: stale current_day marker ($marker_age_seconds seconds old); using system date $(date_today)"
            date_today
            return 0
        fi

        printf '%s' "$marker_date"
        return 0
    fi

    # No marker: before 04:00 in interactive sessions, use previous day
    local current_hour_num
    current_hour_num=$((10#$(date_hour_24)))
    if [ -t 0 ] && [ "$current_hour_num" -lt 4 ]; then
        log_warn "goodevening.sh: startday marker missing before 04:00; using previous day"
        date_shift_days -1 "%Y-%m-%d"
    else
        log_warn "goodevening.sh: startday marker missing; using system date $(date_today)"
        date_today
    fi
}

# 1. Parse arguments and determine session date
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

TODAY=$(determine_session_date "$FORCE_CURRENT_DAY" "$DATE_OVERRIDE")

# Refresh Fitbit data before the evening review.
# That way the reflection can see the latest wearable picture from today.
# If syncing is unavailable, we still finish the rest of the close-out.
if command -v health_ops_auto_sync_fitbit >/dev/null 2>&1; then
    health_ops_auto_sync_fitbit >/dev/null 2>&1 || true
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
    COMPLETED_TASKS=$(filter_entries_by_date "$TODO_DONE_FILE" "$TODAY")
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
    TODAY_JOURNAL_ENTRIES_TEXT=$(filter_entries_by_date "$JOURNAL_FILE" "$TODAY")
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
    TASKS_COMPLETED=$(count_entries_by_date "$TODO_DONE_FILE" "$TODAY")
fi
if [ -f "$JOURNAL_FILE" ]; then
    JOURNAL_ENTRY_COUNT=$(count_entries_by_date "$JOURNAL_FILE" "$TODAY")
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
    _ge_issue_detail_limit="${GOODEVENING_PROJECT_ISSUE_DETAIL_LIMIT:-8}"
    if ! [[ "$_ge_issue_detail_limit" =~ ^[0-9]+$ ]] || [ "$_ge_issue_detail_limit" -lt 1 ]; then
        _ge_issue_detail_limit=8
    fi

    job_count=0
    scanned_projects=0
    tmp_results=$(mktemp -d) || die "Failed to create temp directory" "1"
    trap "rm -rf '$tmp_results'" EXIT
    while IFS= read -r gitdir; do
        scanned_projects=$((scanned_projects + 1))
        (
            proj_dir=$(dirname "$gitdir")
            proj_name=$(basename "$proj_dir")
            result_prefix=$(printf "%03d_%s" "$scanned_projects" "$proj_name")
            if project_has_safety_issue "$proj_dir" "$proj_name" > "$tmp_results/$result_prefix"; then
                mv "$tmp_results/$result_prefix" "$tmp_results/${result_prefix}.issue"
            else
                rm -f "$tmp_results/$result_prefix"
            fi
        ) &
        job_count=$((job_count + 1))
        if [ "$job_count" -ge "$_ge_scan_jobs" ]; then
            wait
            job_count=0
        fi
    done < <(find "$PROJECTS_DIR" -maxdepth 2 -type d -name ".git" 2>/dev/null | sort | head -n "$_ge_scan_limit")

    wait

    issue_count=$(find "$tmp_results" -type f -name "*.issue" 2>/dev/null | wc -l | tr -d ' ')
    shown_issue_count=0
    if [ "$issue_count" -gt 0 ]; then
        found_issues=true
        echo "  • $issue_count project(s) with safety issues across $scanned_projects scanned repo(s)"
        while IFS= read -r issue_file; do
            [ -z "$issue_file" ] && continue
            if [ "$shown_issue_count" -ge "$_ge_issue_detail_limit" ]; then
                break
            fi
            cat "$issue_file"
            shown_issue_count=$((shown_issue_count + 1))
        done < <(find "$tmp_results" -type f -name "*.issue" 2>/dev/null | sort)

        hidden_issue_count=$((issue_count - shown_issue_count))
        if [ "$hidden_issue_count" -gt 0 ]; then
            echo "  • $hidden_issue_count more project(s) not shown"
        fi
    fi

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

    # The evening coach follows the same broad pattern as startday:
    # gather facts, build a prompt, ask the AI, then print a reflection.
    # TODAY is already set globally above, including refresh/override handling.
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
    # Build the shared digest so the evening coach can see work patterns,
    # energy patterns, and the newest wearable context in one place.
    if command -v coaching_build_behavior_digest >/dev/null 2>&1; then
        COACH_BEHAVIOR_DIGEST=$(coaching_build_behavior_digest "$TODAY" "$COACH_TACTICAL_DAYS" "$COACH_PATTERN_DAYS" "${RECENT_PUSHES:-}" "${TODAY_COMMITS:-}" 2>/dev/null || echo "(behavior digest unavailable)")
    fi

    # Build the AI's instruction letter for the evening reflection.
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

    _ge_git_combined=$(printf '%s\n%s\n' "${TODAY_COMMITS:-}" "${RECENT_PUSHES:-}")
    
    # Ask the AI to write the reflection itself.
    if command -v coaching_generate_response >/dev/null 2>&1; then
        REFLECTION=$(coaching_generate_response "$REFLECTION_PROMPT" "$COACH_TEMPERATURE" "${FOCUS_CONTEXT:-"(no focus set)"}" "$COACH_MODE" "$_ge_git_combined" "${COACH_BEHAVIOR_DIGEST:-}" "goodevening")
    else
        REFLECTION="Unable to generate AI reflection at this time."
    fi

    echo "$REFLECTION" | sed 's/^/  /'
    _COACH_CHAT_BRIEFING="$REFLECTION"

    # Just like startday, this gives a small confidence label for the reflection.
    # It tells us whether the AI had enough evidence to make a strong call.
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
