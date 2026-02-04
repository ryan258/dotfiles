#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE_UTILS="$SCRIPT_DIR/lib/date_utils.sh"
if [ -f "$DATE_UTILS" ]; then
    # shellcheck disable=SC1090
    source "$DATE_UTILS"
else
    echo "Error: date utilities not found at $DATE_UTILS" >&2
    exit 1
fi

# --- Configuration ---
if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/config.sh"
else
    if [ -f "$SCRIPT_DIR/../.env" ]; then
        # shellcheck disable=SC1090
        source "$SCRIPT_DIR/../.env"
    fi
fi

STATE_DIR="${DATA_DIR:-${STATE_DIR:-$HOME/.config/dotfiles-data}}"
mkdir -p "$STATE_DIR"

SYSTEM_LOG_FILE="${SYSTEM_LOG:-$STATE_DIR/system.log}"
TODO_DONE_FILE="${DONE_FILE:-${TODO_DONE_FILE:-$STATE_DIR/todo_done.txt}}"
JOURNAL_FILE="${JOURNAL_FILE:-$STATE_DIR/journal.txt}"
FOCUS_FILE="${FOCUS_FILE:-$STATE_DIR/daily_focus.txt}"
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
    CURRENT_DAY_FILE="$STATE_DIR/current_day"

    if [ -f "$CURRENT_DAY_FILE" ]; then
        TODAY=$(cat "$CURRENT_DAY_FILE")
        if [ "$FORCE_CURRENT_DAY" = false ]; then
            # If the file is extremely old (e.g. > 24 hours), fallback to actual today to prevent stale state bugs
            FILE_AGE=$(( $(date +%s) - $(date -r "$CURRENT_DAY_FILE" +%s) ))
            if [ "$FILE_AGE" -gt 86400 ]; then
                 TODAY=$(date +%Y-%m-%d)
            fi
        fi
    else
        # Fallback logic
        HOUR=$(date +%H)
        if [ "$HOUR" -lt 4 ]; then
            TODAY=$(date_shift_days -1 "%Y-%m-%d")
        else
            TODAY=$(date +%Y-%m-%d)
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
    JOURNAL_ENTRIES=$(awk -F'|' -v today="$TODAY" '$1 ~ "^"today {print}' "$JOURNAL_FILE")
    if [ -n "$JOURNAL_ENTRIES" ]; then
        echo "$JOURNAL_ENTRIES" | sed 's/^/  • /'
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
else
    echo "  (github_helper.sh not found)"
fi

# --- Gamify Progress ---
echo ""
echo "🌟 TODAY'S WINS:"
TASKS_COMPLETED=$(awk -F'|' -v today="$TODAY" '$1 ~ "^"today {count++} END {print count+0}' "$TODO_DONE_FILE")
JOURNAL_ENTRIES=$(awk -F'|' -v today="$TODAY" '$1 ~ "^"today {count++} END {print count+0}' "$JOURNAL_FILE")

if [ "$TASKS_COMPLETED" -gt 0 ]; then
    echo "  🎉 Win: You completed $TASKS_COMPLETED task(s) today. Progress is progress."
fi

if [ "$JOURNAL_ENTRIES" -gt 0 ]; then
    echo "  🧠 Win: You logged $JOURNAL_ENTRIES entries. Context captured."
fi

if [ "$TASKS_COMPLETED" -eq 0 ] && [ "$JOURNAL_ENTRIES" -eq 0 ]; then
    echo "  🧘 Today was a rest day. Logging off is a valid and productive choice."
fi

# 3. Automation Safety Nets - Check projects for potential issues
echo ""
echo "🚀 PROJECT SAFETY CHECK:"
if [ -d "$PROJECTS_DIR" ]; then
    found_issues=false

    # Create a temp file to track issues found in subshells
    ISSUES_LOG=$(mktemp)
    
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
                echo "issue" >> "$ISSUES_LOG"
            fi
        )
    done < <(find "$PROJECTS_DIR" -maxdepth 2 -type d -name ".git")

    if [ -s "$ISSUES_LOG" ]; then
        found_issues=true
    fi
    rm "$ISSUES_LOG"

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
    TODAY_TASKS=$(awk -F'|' -v today="$TODAY" '$1 ~ "^"today {print}' "$TODO_DONE_FILE" 2>/dev/null || echo "")
    TODAY_JOURNAL=$(awk -F'|' -v today="$TODAY" '$1 ~ "^"today {print}' "$JOURNAL_FILE" 2>/dev/null || echo "")
    FOCUS_CONTEXT=""
    if [ -f "$FOCUS_FILE" ] && [ -s "$FOCUS_FILE" ]; then
        FOCUS_CONTEXT=$(cat "$FOCUS_FILE")
    fi

    if [ -z "$TODAY_TASKS$TODAY_JOURNAL$FOCUS_CONTEXT$RECENT_PUSHES" ]; then
        echo "  (No focus, pushes, tasks, or journal entries to reflect on for $TODAY)"
    elif ! command -v dhp-strategy.sh &> /dev/null; then
         echo "  (AI Staff tools not found in PATH)"
    else
        # Generate reflection via AI
        REFLECTION=$({
            echo "Provide a brief daily reflection (3-5 sentences)."
            echo "Primary signals are today's focus and recent GitHub pushes; use them first."
            echo "Secondary signals are tasks and journal entries."
            echo ""
            echo "Today's focus:"
            echo "${FOCUS_CONTEXT:-"(no focus set)"}"
            echo ""
            echo "Recent GitHub pushes (last 7 days):"
            echo "${RECENT_PUSHES:-"(none)"}"
            echo ""
            if [ -n "$TODAY_TASKS" ]; then
                echo "Completed tasks:"
                echo "$TODAY_TASKS"
                echo ""
            fi
            if [ -n "$TODAY_JOURNAL" ]; then
                echo "Journal entries:"
                echo "$TODAY_JOURNAL"
                echo ""
            fi
            echo "Provide:"
            echo "- One insight or capability gained today"
            echo "- One outcome suggested by the pushes"
            echo "- One smallest next step for tomorrow"
            echo ""
            echo "Keep it thoughtful, reflective, and energy-aware."
        } | dhp-strategy.sh 2>/dev/null || echo "Unable to generate AI reflection at this time.")

        echo "$REFLECTION" | sed 's/^/  /'
    fi
fi

echo ""
echo "Evening wrap-up complete. Have a great night!"
