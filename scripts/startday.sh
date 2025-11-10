#!/bin/bash
set -euo pipefail
# startday.sh - Enhanced morning routine

SYSTEM_LOG_FILE="$HOME/.config/dotfiles-data/system.log"
echo "$(date): startday.sh - Running morning routine." >> "$SYSTEM_LOG_FILE"

# Load environment variables for optional AI features
if [ -f "$HOME/dotfiles/.env" ]; then
    source "$HOME/dotfiles/.env"
fi

BLOG_SCRIPT="$HOME/dotfiles/scripts/blog.sh"
BLOG_DIR_CONFIGURED="${BLOG_DIR:-}"
BLOG_CONTENT_ROOT="${BLOG_CONTENT_DIR:-}"
if [ -z "$BLOG_CONTENT_ROOT" ] && [ -n "$BLOG_DIR_CONFIGURED" ]; then
    BLOG_CONTENT_ROOT="$BLOG_DIR_CONFIGURED/content"
fi
BLOG_READY=false
if [ -f "$BLOG_SCRIPT" ] && [ -n "$BLOG_DIR_CONFIGURED" ] && [ -d "$BLOG_CONTENT_ROOT" ]; then
    BLOG_READY=true
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

# --- WEEKLY REVIEW ---
if [ $(date +%u) -eq 1 ]; then
    WEEK_NUM=$(date -v-1d +%V)
    YEAR=$(date -v-1d +%Y)
    REVIEW_FILE="$HOME/Documents/Reviews/Weekly/$YEAR-W$WEEK_NUM.md"
    if [ -f "$REVIEW_FILE" ]; then
        echo ""
        echo "📈 LAST WEEK'S REVIEW:"
        echo "  • Last week's review is available at: $REVIEW_FILE"
    fi
fi


# --- ACTIVE PROJECTS (from GitHub) ---
echo ""
echo "🚀 ACTIVE PROJECTS (pushed to GitHub in last 7 days):"
HELPER_SCRIPT="$HOME/dotfiles/scripts/github_helper.sh"
if [ -f "$HELPER_SCRIPT" ]; then
    if GITHUB_REPOS=$("$HELPER_SCRIPT" list_repos 2>/dev/null); then
        echo "$GITHUB_REPOS" | jq -r '.[] | "\(.pushed_at) \(.name)"' | while read -r line; do
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
    else
        echo "  ⚠️ Unable to fetch GitHub activity. Check your token or network."
    fi
fi

# --- SUGGESTED DIRECTORIES ---
echo ""
echo "💡 SUGGESTED DIRECTORIES:"
if [ -f "$HOME/dotfiles/scripts/g.sh" ]; then
    "$HOME/dotfiles/scripts/g.sh" suggest | head -n 3 | awk '{print "  • " $2}'
fi

# --- BLOG STATUS ---
if [ "$BLOG_READY" = true ]; then
    echo ""
    if ! "$BLOG_SCRIPT" status; then
        echo "  ⚠️ Blog status unavailable (check BLOG_DIR configuration)."
    fi
    if [ -f "$HOME/dotfiles/scripts/blog_recent_content.sh" ]; then
        echo ""
        echo "📰 LATEST BLOG CONTENT:"
        if ! "$HOME/dotfiles/scripts/blog_recent_content.sh" 3; then
            echo "  ⚠️ Unable to list recent content (check BLOG_CONTENT_DIR)."
        fi
    fi
fi

# --- Helpers ---
parse_timestamp() {
    local raw="$1" epoch=""

    # Full datetime with minutes (preferred)
    if epoch=$(date -j -f "%Y-%m-%d %H:%M" "$raw" +%s 2>/dev/null); then
        echo "$epoch"
        return
    fi

    # Datetime missing minutes (e.g., "2025-11-18 11")
    if [[ "$raw" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]]+([0-9]{1,2})$ ]]; then
        local padded_hour
        printf -v padded_hour "%02d:00" "${BASH_REMATCH[2]}"
        local normalized="${BASH_REMATCH[1]} ${padded_hour}"
        if epoch=$(date -j -f "%Y-%m-%d %H:%M" "$normalized" +%s 2>/dev/null); then
            echo "$epoch"
            return
        fi
    fi

    # Date-only entries
    if epoch=$(date -j -f "%Y-%m-%d" "$raw" +%s 2>/dev/null); then
        echo "$epoch"
        return
    fi

    echo "0"
}

# --- HEALTH ---
echo ""
echo "🏥 HEALTH:"
HEALTH_FILE="$HOME/.config/dotfiles-data/health.txt"
if [ -f "$HEALTH_FILE" ] && [ -s "$HEALTH_FILE" ]; then
    # Show upcoming appointments
    if grep -q "^APPT|" "$HEALTH_FILE" 2>/dev/null; then
        grep "^APPT|" "$HEALTH_FILE" | sort -t'|' -k2 | while IFS='|' read -r type appt_date desc; do
            appt_epoch=$(parse_timestamp "$appt_date")
            if [ "$appt_epoch" -le 0 ]; then
                continue
            fi
            days_until=$(( ( appt_epoch - $(date +%s) ) / 86400 ))
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

# --- AI BRIEFING (Optional) ---
if [ "${AI_BRIEFING_ENABLED:-false}" = "true" ]; then
    echo ""
    echo "🤖 AI BRIEFING:"

    # Cache file for today's briefing
    BRIEFING_CACHE="$HOME/.config/dotfiles-data/.ai_briefing_cache"
    TODAY=$(date '+%Y-%m-%d')

    # Check if we already have today's briefing
    if [ -f "$BRIEFING_CACHE" ] && grep -q "^$TODAY|" "$BRIEFING_CACHE"; then
        echo "  (Cached from this morning)"
        grep "^$TODAY|" "$BRIEFING_CACHE" | cut -d'|' -f2- | sed 's/^/  /'
    else
        # Generate new briefing
        JOURNAL_FILE="$HOME/.config/dotfiles-data/journal.txt"
        TODO_FILE="$HOME/.config/dotfiles-data/todo.txt"

        # Gather context
        RECENT_JOURNAL=$(tail -n 5 "$JOURNAL_FILE" 2>/dev/null || echo "")
        TODAY_TASKS=$(head -n 5 "$TODO_FILE" 2>/dev/null || echo "")

        if command -v dhp-strategy.sh &> /dev/null && [ -n "$RECENT_JOURNAL" ]; then
            # Generate briefing via AI
            BRIEFING=$({
                echo "Provide a brief daily focus suggestion (2-3 sentences) based on:"
                echo ""
                echo "Recent journal entries:"
                echo "$RECENT_JOURNAL"
                echo ""
                echo "Top tasks:"
                echo "$TODAY_TASKS"
                echo ""
                echo "Keep it actionable and encouraging."
            } | dhp-strategy.sh 2>/dev/null || echo "Unable to generate AI briefing at this time.")

            # Cache the briefing
            echo "$TODAY|$BRIEFING" > "$BRIEFING_CACHE"
            echo "$BRIEFING" | sed 's/^/  /'
        else
            echo "  (Enable AI briefing: Set AI_BRIEFING_ENABLED=true in .env)"
        fi
    fi
fi

echo ""
echo "💡 Quick commands: todo add | journal | goto | backup"
echo "════════════════════════════════════════════════════════════"
