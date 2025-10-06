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

# --- ACTIVE PROJECTS ---
echo ""
echo "🚀 ACTIVE PROJECTS (modified in last 7 days):"
if [ -d "$HOME/Projects" ]; then
    find "$HOME/Projects" -maxdepth 1 -type d -mtime -7 2>/dev/null | while read -r project; do
        if [ -d "$project/.git" ]; then
            project_name=$(basename "$project")
            last_commit=$(cd "$project" && git log -1 --format="%ar: %s" 2>/dev/null)
            echo "  • $project_name - $last_commit"
        fi
    done
fi

# --- BLOG STATUS ---
echo ""
echo "📝 BLOG STATUS (ryanleej.com):"
if [ -d "$HOME/Projects/my-ms-ai-blog" ]; then
    stub_count=$(grep -l "content stub" "$HOME/Projects/my-ms-ai-blog/content/posts/"*.md 2>/dev/null | wc -l | tr -d ' ')
    total_posts=$(ls "$HOME/Projects/my-ms-ai-blog/content/posts/"*.md 2>/dev/null | wc -l | tr -d ' ')
    echo "  • Total posts: $total_posts"
    echo "  • Posts needing content: $stub_count"
    echo "  • Site: https://ryanleej.com"
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