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
SYSTEM_LOG_FILE="$HOME/.config/dotfiles-data/system.log"
TODO_DONE_FILE="$HOME/.config/dotfiles-data/todo_done.txt"
JOURNAL_FILE="$HOME/.config/dotfiles-data/journal.txt"
PROJECTS_DIR=~/Projects

# Load environment variables for optional AI features
if [ -f "$HOME/dotfiles/.env" ]; then
    source "$HOME/dotfiles/.env"
fi


# 1. Determine "Today"
# Usage: goodevening.sh [YYYY-MM-DD]
if [ -n "${1:-}" ]; then
    TODAY="$1"
    echo "📅 Overriding date to: $TODAY"
else
    STATE_DIR="${STATE_DIR:-$HOME/.config/dotfiles-data}"
    CURRENT_DAY_FILE="$STATE_DIR/current_day"

    if [ -f "$CURRENT_DAY_FILE" ]; then
        TODAY=$(cat "$CURRENT_DAY_FILE")
        # If the file is extremely old (e.g. > 24 hours), fallback to actual today to prevent stale state bugs
        FILE_AGE=$(( $(date +%s) - $(date -r "$CURRENT_DAY_FILE" +%s) ))
        if [ "$FILE_AGE" -gt 86400 ]; then
             TODAY=$(date +%Y-%m-%d)
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

# 1. Show completed tasks from today
echo ""
echo "✅ COMPLETED TODAY:"
if [ -f "$TODO_DONE_FILE" ]; then
    COMPLETED_TASKS=$(grep "\[$TODAY" "$TODO_DONE_FILE" || true)
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
    JOURNAL_ENTRIES=$(grep "\[$TODAY" "$JOURNAL_FILE" || true)
    if [ -n "$JOURNAL_ENTRIES" ]; then
        echo "$JOURNAL_ENTRIES" | sed 's/^/  • /'
    else
        echo "  (No journal entries for today)"
    fi
fi

# 3. Time Tracking Summary
echo ""
echo "⏱️  TIME TRACKED TODAY:"
# Correctly define SCRIPT_DIR if not already available or redeclare to be safe
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TIME_TRACKER="${SCRIPT_DIR}/time_tracker.sh"
if [ -x "$TIME_TRACKER" ]; then
    # We use a subshell or call a function to get today's report
    # Since report command in wrapper calls generate_time_report which is a stub...
    # We should actually implement a simple daily summary here or in the library.
    # For now, let's just list the entries for today from the log file manually or via a simple grep
    # TODAY is valid
    TIME_LOG="$HOME/.config/dotfiles-data/time_tracking.txt"
    if [ -f "$TIME_LOG" ]; then
        TODAY_ENTRIES=$(grep "|$TODAY" "$TIME_LOG" || true)
        if [ -n "$TODAY_ENTRIES" ]; then
             echo "  (Time reporting details coming in Phase 1)"
             echo "$TODAY_ENTRIES" | head -n 5 | sed 's/^/  • /' 
             if [ $(echo "$TODAY_ENTRIES" | wc -l) -gt 5 ]; then
                echo "  • ... and more"
             fi
        else
            echo "  (No time tracked today)"
        fi
    else
        echo "  (No time log found)"
    fi
else
    echo "  (Time tracker not found)"
fi

# --- Gamify Progress ---
echo ""
echo "🌟 TODAY'S WINS:"
TASKS_COMPLETED=$(grep -c "\[$TODAY" "$TODO_DONE_FILE" || true)
JOURNAL_ENTRIES=$(grep -c "\[$TODAY" "$JOURNAL_FILE" || true)

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



# 7. Clear completed tasks older than 7 days
echo ""
echo "🧹 Tidying up old completed tasks..."
if [ -f "$TODO_DONE_FILE" ]; then
    CUTOFF_DATE_STR=$(date_shift_days -7 "%Y-%m-%d")
    tasks_to_remove=$(awk -v cutoff="$CUTOFF_DATE_STR" '$0 ~ /^\[/ { date_str = substr($1, 2, 10); if (date_str < cutoff) { print } }' "$TODO_DONE_FILE" | wc -l | tr -d ' ')
    echo "$(date): goodevening.sh - Cleaned $tasks_to_remove old tasks." >> "$SYSTEM_LOG_FILE"
    awk -v cutoff="$CUTOFF_DATE_STR" '
        $0 ~ /^\[/ {
            date_str = substr($1, 2, 10)
            if (date_str >= cutoff) {
                print
            }
        }
        $0 !~ /^\[/ { print } # print lines without date
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
    TODAY_TASKS=$(grep "\[$TODAY" "$TODO_DONE_FILE" 2>/dev/null || echo "")
    TODAY_JOURNAL=$(grep "\[$TODAY" "$JOURNAL_FILE" 2>/dev/null || echo "")

    if [ -z "$TODAY_TASKS$TODAY_JOURNAL" ]; then
        echo "  (No tasks or journal entries to reflect on for $TODAY)"
    elif ! command -v dhp-strategy.sh &> /dev/null; then
         echo "  (AI Staff tools not found in PATH)"
    else
        # Generate reflection via AI
        REFLECTION=$({
            echo "Provide a brief daily reflection (2-3 sentences) that specifically looks for insights gained, knowledge patterns, and capability improvements."
            echo "Celebrate learning and deep understanding, not just output or revenue."
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
            echo "- One curiosity to follow tomorrow"
            echo ""
            echo "Keep it thoughtful and insight-oriented."
        } | dhp-strategy.sh 2>/dev/null || echo "Unable to generate AI reflection at this time.")

        echo "$REFLECTION" | sed 's/^/  /'
    fi
fi

echo ""
echo "Evening wrap-up complete. Have a great night!"
