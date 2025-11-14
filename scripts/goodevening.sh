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

echo "=== Evening Close-Out — $(date '+%Y-%m-%d %H:%M') ==="

# 1. Show completed tasks from today
echo ""
echo "✅ COMPLETED TODAY:"
if [ -f "$TODO_DONE_FILE" ]; then
    TODAY=$(date +%Y-%m-%d)
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
    TODAY=$(date +%Y-%m-%d)
    JOURNAL_ENTRIES=$(grep "\[$TODAY" "$JOURNAL_FILE" || true)
    if [ -n "$JOURNAL_ENTRIES" ]; then
        echo "$JOURNAL_ENTRIES" | sed 's/^/  • /'
    else
        echo "  (No journal entries for today)"
    fi
fi

# --- Gamify Progress ---
echo ""
echo "🌟 TODAY'S WINS:"
TASKS_COMPLETED=$(grep -c "\[$(date +%Y-%m-%d)" "$TODO_DONE_FILE" || true)
JOURNAL_ENTRIES=$(grep -c "\[$(date +%Y-%m-%d)" "$JOURNAL_FILE" || true)

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

    while IFS= read -r gitdir; do
        proj_dir=$(dirname "$gitdir")
        proj_name=$(basename "$proj_dir")

        (
            cd "$proj_dir" || exit

            # Check for uncommitted changes
            if git status --porcelain | grep -q .; then
                change_count=$(git status --porcelain | wc -l | tr -d ' ')
                echo "  ⚠️  $proj_name: $change_count uncommitted changes"
                found_issues=true

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
                        found_issues=true

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
                            found_issues=true
                        elif [ "$unpushed" -gt 0 ]; then
                            echo "  📤 $proj_name: $unpushed unpushed commit(s) on $current_branch"
                            found_issues=true
                        fi
                    fi
                fi
            fi
        )
    done < <(find "$PROJECTS_DIR" -maxdepth 2 -type d -name ".git")

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
    TODAY=$(date +%Y-%m-%d)
    TODAY_TASKS=$(grep "\[$TODAY" "$TODO_DONE_FILE" 2>/dev/null || echo "")
    TODAY_JOURNAL=$(grep "\[$TODAY" "$JOURNAL_FILE" 2>/dev/null || echo "")

    if command -v dhp-strategy.sh &> /dev/null && [ -n "$TODAY_TASKS$TODAY_JOURNAL" ]; then
        # Generate reflection via AI
        REFLECTION=$({
            echo "Provide a brief daily reflection (2-3 sentences) based on today's activities:"
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
            echo "- One key accomplishment to celebrate"
            echo "- One suggestion for tomorrow"
            echo ""
            echo "Keep it encouraging and actionable."
        } | dhp-strategy.sh 2>/dev/null || echo "Unable to generate AI reflection at this time.")

        echo "$REFLECTION" | sed 's/^/  /'
    else
        echo "  (Enable AI reflection: Set AI_REFLECTION_ENABLED=true in .env)"
    fi
fi

echo ""
echo "Evening wrap-up complete. Have a great night!"
