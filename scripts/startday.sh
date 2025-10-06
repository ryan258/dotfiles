#!/bin/bash
# startday.sh - Enhanced morning routine

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Good morning! $(date '+%A, %B %d, %Y - %H:%M')            "
echo "╚════════════════════════════════════════════════════════════╝"

# --- YESTERDAY'S CONTEXT ---
echo ""
echo "📅 YESTERDAY YOU WERE:"
# Show last 3 journal entries or git commits
if [ -f ~/.daily_journal.txt ]; then
    echo "Journal entries:"
    tail -n 3 ~/.daily_journal.txt | sed 's/^/  • /'
fi

# --- ACTIVE PROJECTS (from GitHub) ---
echo ""
echo "🚀 ACTIVE PROJECTS (pushed to GitHub in last 7 days):"
HELPER_SCRIPT="$HOME/dotfiles/scripts/github_helper.sh"
if [ -f "$HELPER_SCRIPT" ]; then
    "$HELPER_SCRIPT" list_repos | jq -r '.[] | "\(.pushed_at) \(.name)"' | while read -r line; do
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
            echo "  • $repo_name (pushed $day_text)"
        else
            break
        fi
    done
fi

# --- BLOG STATUS ---
echo ""
if [ -f "$HOME/dotfiles/scripts/blog.sh" ]; then
    "$HOME/dotfiles/scripts/blog.sh" status
fi

# --- HEALTH ---
echo ""
echo "🏥 HEALTH:"
HEALTH_FILE="$HOME/.health_appointments.txt"
if [ -f "$HEALTH_FILE" ] && [ -s "$HEALTH_FILE" ]; then
    sort "$HEALTH_FILE" | while IFS='|' read -r appt_date desc; do
        days_until=$(( ( $(date -j -f "%Y-%m-%d %H:%M" "$appt_date" +%s 2>/dev/null || echo 0) - $(date +%s) ) / 86400 ))
        if [ "$days_until" -ge 0 ]; then
            echo "  • $desc - $appt_date (in $days_until days)"
        fi
    done
else
    echo "  (no appointments tracked - add with: health add \"description\" \"date\")"
fi

# --- TODAY'S TASKS ---
echo ""
echo "✅ TODAY'S TASKS:"
if [ -f ~/.todo_list.txt ] && [ -s ~/.todo_list.txt ]; then
    cat -n ~/.todo_list.txt | sed 's/^/  /'
else
    echo "  (no tasks yet - add with: todo add 'task name')"
fi

echo ""
echo "💡 Quick commands: todo add | journal | goto | backup"
echo "════════════════════════════════════════════════════════════"