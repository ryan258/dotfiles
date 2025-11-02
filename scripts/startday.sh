#!/bin/bash
set -euo pipefail
# startday.sh - Enhanced morning routine

SYSTEM_LOG_FILE="$HOME/.config/dotfiles-data/system.log"
echo "$(date): startday.sh - Running morning routine." >> "$SYSTEM_LOG_FILE"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Good morning! $(date '+%A, %B %d, %Y - %H:%M')            "
echo "╚════════════════════════════════════════════════════════════╝"

# --- Sync Blog Tasks ---
if [ -f "$HOME/dotfiles/scripts/blog.sh" ]; then
    "$HOME/dotfiles/scripts/blog.sh" sync
fi

# --- YESTERDAY'S CONTEXT ---
JOURNAL_FILE="$HOME/.config/dotfiles-data/journal.txt"
echo ""
echo "📅 YESTERDAY YOU WERE:"
# Show last 3 journal entries or git commits
if [ -f "$JOURNAL_FILE" ]; then
    echo "Journal entries:"
    tail -n 3 "$JOURNAL_FILE" | sed 's/^/  • /'
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
HEALTH_FILE="$HOME/.config/dotfiles-data/health.txt"
if [ -f "$HEALTH_FILE" ] && [ -s "$HEALTH_FILE" ]; then
    # Show upcoming appointments
    if grep -q "^APPT|" "$HEALTH_FILE" 2>/dev/null; then
        grep "^APPT|" "$HEALTH_FILE" | sort -t'|' -k2 | while IFS='|' read -r type appt_date desc; do
            days_until=$(( ( $(date -j -f "%Y-%m-%d %H:%M" "$appt_date" +%s 2>/dev/null || echo 0) - $(date +%s) ) / 86400 ))
            if [ "$days_until" -ge 0 ]; then
                echo "  • $desc - $appt_date (in $days_until days)"
            fi
        done
    fi

    # Show today's health snapshot if available
    today=$(date '+%Y-%m-%d')
    if grep -q "^ENERGY|$today" "$HEALTH_FILE" 2>/dev/null; then
        today_energy=$(grep "^ENERGY|$today" "$HEALTH_FILE" | tail -1 | cut -d'|' -f3)
        echo "  Energy level: $today_energy/10"
    fi

    if grep -q "^SYMPTOM|$today" "$HEALTH_FILE" 2>/dev/null; then
        symptom_count=$(grep -c "^SYMPTOM|$today" "$HEALTH_FILE")
        echo "  Symptoms logged today: $symptom_count (run 'health list' to see)"
    fi

    # If no data shown, display help
    if ! grep -q "^APPT\|^ENERGY\|^SYMPTOM" "$HEALTH_FILE" 2>/dev/null; then
        echo "  (no data tracked - try: health add, health energy, health symptom)"
    fi
else
    echo "  (no data tracked - try: health add, health energy, health symptom)"
fi

# --- SCHEDULED TASKS ---
echo ""
echo "🗓️  SCHEDULED TASKS:"
if command -v atq >/dev/null 2>&1; then
    atq | sed 's/^/  /' || echo "  (No scheduled tasks)"
else
    echo "  (at command not available)"
fi

# --- STALE TASKS (older than 7 days) ---
STALE_TODO_FILE="$HOME/.config/dotfiles-data/todo.txt"
echo ""
echo "⏰ STALE TASKS:"
if [ -f "$STALE_TODO_FILE" ] && [ -s "$STALE_TODO_FILE" ]; then
    CUTOFF_DATE=$(date -v-7d '+%Y-%m-%d')
    awk -F'|' -v cutoff="$CUTOFF_DATE" '$1 < cutoff { printf "  • %s (from %s)\n", $2, $1 }' "$STALE_TODO_FILE"
fi

# --- TODAY'S TASKS ---
TODO_FILE="$HOME/.config/dotfiles-data/todo.txt"
echo ""
echo "✅ TODAY'S TASKS:"
if [ -f "$HOME/dotfiles/scripts/todo.sh" ]; then
    "$HOME/dotfiles/scripts/todo.sh" top 3
else
    echo "  (todo.sh not found)"
fi

echo ""
echo "💡 Quick commands: todo add | journal | goto | backup"
echo "════════════════════════════════════════════════════════════"