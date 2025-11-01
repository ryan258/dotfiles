#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
TODO_DONE_FILE="$HOME/.config/dotfiles-data/todo_done.txt"
JOURNAL_FILE="$HOME/.config/dotfiles-data/journal.txt"
PROJECTS_DIR=~/Projects

echo "=== Evening Close-Out — $(date '+%Y-%m-%d %H:%M') ==="

# 1. Show completed tasks from today
echo ""
echo "✅ COMPLETED TODAY:"
if [ -f "$TODO_DONE_FILE" ]; then
    TODAY=$(date +%Y-%m-%d)
    grep "\[$TODAY" "$TODO_DONE_FILE" | sed 's/^/  • /' || echo "  (No tasks completed today)"
fi

# 2. Show today's journal entries
echo ""
echo "📝 TODAY'S JOURNAL:"
if [ -f "$JOURNAL_FILE" ]; then
    TODAY=$(date +%Y-%m-%d)
    grep "\[$TODAY" "$JOURNAL_FILE" | sed 's/^/  • /' || echo "  (No journal entries for today)"
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
            default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

            if [ "$current_branch" != "$default_branch" ] && [ "$current_branch" != "main" ] && [ "$current_branch" != "master" ]; then
                # Check how old this branch is
                branch_age_days=$(( ( $(date +%s) - $(git log -1 --format=%ct "$current_branch" 2>/dev/null || echo 0) ) / 86400 ))

                if [ "$branch_age_days" -gt 7 ]; then
                    echo "  ⚠️  $proj_name: On branch '$current_branch' (${branch_age_days} days old)"
                    found_issues=true

                    # Check if branch is pushed to remote
                    if ! git ls-remote --heads origin "$current_branch" 2>/dev/null | grep -q .; then
                        echo "      └─ Branch not pushed to remote"
                    fi
                fi
            fi

            # Check for unpushed commits on default branch
            if [ "$current_branch" = "$default_branch" ] || [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
                if git rev-parse @{u} >/dev/null 2>&1; then
                    unpushed=$(git rev-list @{u}..HEAD --count 2>/dev/null || echo "0")
                    if [ "$unpushed" -gt 0 ]; then
                        echo "  📤 $proj_name: $unpushed unpushed commit(s) on $current_branch"
                        found_issues=true
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

# 4. Health check-in
echo ""
echo "💊 HEALTH CHECK-IN:"
HEALTH_FILE="$HOME/.config/dotfiles-data/health.txt"
today=$(date '+%Y-%m-%d')

# Check if energy was logged today
today_energy=$(grep "^ENERGY|$today" "$HEALTH_FILE" 2>/dev/null | tail -1 | cut -d'|' -f3)
if [ -n "$today_energy" ]; then
    echo "  Energy level logged: $today_energy/10"
else
    IFS= read -r -p "How was your energy today (1-10)? (Press Enter to skip) " energy_input
    if [ -n "$energy_input" ]; then
        bash "$(dirname "$0")/health.sh" energy "$energy_input"
    fi
fi

# Check if symptoms were logged
symptom_count=$(grep -c "^SYMPTOM|$today" "$HEALTH_FILE" 2>/dev/null || echo "0")
if [ "$symptom_count" -gt 0 ]; then
    echo "  Symptoms logged today: $symptom_count"
fi

# 5. Prompt for tomorrow's note
echo ""
IFS= read -r -p "What should tomorrow-you remember about today? (Press Enter to skip) " note
if [ -n "$note" ]; then
    # 6. Add response to journal
    # Assuming journal.sh is in the same directory or in PATH
    "$(dirname "$0")/journal.sh" "EOD Note: $note"
fi

# 7. Clear completed tasks older than 7 days
echo ""
echo "🧹 Tidying up old completed tasks..."
if [ -f "$TODO_DONE_FILE" ]; then
    CUTOFF_DATE_STR=$(date -v-7d '+%Y-%m-%d')
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

echo ""
echo "Evening wrap-up complete. Have a great night!"
