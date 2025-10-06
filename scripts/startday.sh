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
if [ -d "$HOME/projects" ]; then
    find "$HOME/projects" -maxdepth 1 -type d -mtime -7 | while read -r project; do
        if [ -d "$project/.git" ]; then
            project_name=$(basename "$project")
            last_commit=$(cd "$project" && git log -1 --format="%ar: %s" 2>/dev/null)
            echo "  • $project_name - $last_commit"
        fi
    done
fi

# --- BLOG STATUS ---
echo ""
echo "📝 BLOG STATUS:"
if [ -d "$HOME/projects/my-ms-ai-blog" ]; then
    stub_count=$(grep -l "content stub" "$HOME/projects/my-ms-ai-blog/content/posts/"*.md 2>/dev/null | wc -l | tr -d ' ')
    total_posts=$(ls "$HOME/projects/my-ms-ai-blog/content/posts/"*.md 2>/dev/null | wc -l | tr -d ' ')
    echo "  • Total posts: $total_posts"
    echo "  • Stubs needing content: $stub_count"
fi

# --- HEALTH REMINDERS ---
echo ""
echo "🏥 HEALTH:"
if [ -f ~/.health_reminders.txt ]; then
    cat ~/.health_reminders.txt | sed 's/^/  • /'
else
    echo "  • Neurologist follow-up: November 2025"
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