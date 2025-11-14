#!/bin/bash
set -euo pipefail

# ai_suggest.sh: Context-Aware Dispatcher Suggestion System
# Analyzes current context and suggests relevant AI dispatchers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE_UTILS="$SCRIPT_DIR/lib/date_utils.sh"
if [ -f "$DATE_UTILS" ]; then
    # shellcheck disable=SC1090
    source "$DATE_UTILS"
else
    echo "Error: date utilities not found at $DATE_UTILS" >&2
    exit 1
fi

DATA_DIR="$HOME/.config/dotfiles-data"
TODO_FILE="$DATA_DIR/todo.txt"
JOURNAL_FILE="$DATA_DIR/journal.txt"

echo "🔍 Analyzing your current context..."
echo ""

# Collect context signals
CONTEXT=""
SUGGESTIONS=()

# 1. Current directory context
CURRENT_DIR=$(pwd)
DIR_NAME=$(basename "$CURRENT_DIR")
CONTEXT+="Current directory: $CURRENT_DIR\n"

# Check if we're in a known project directory
if [[ "$CURRENT_DIR" == *"dotfiles"* ]]; then
    SUGGESTIONS+=("💻 **Tech Dispatcher**: Debug or optimize dotfiles scripts")
    SUGGESTIONS+=("   echo \"Analyze error handling patterns\" | tech")
fi

if [[ "$CURRENT_DIR" == *"blog"* ]] || [[ "$CURRENT_DIR" == *"ryanleej"* ]]; then
    SUGGESTIONS+=("📝 **Content Dispatcher**: Generate or refine blog content")
    SUGGESTIONS+=("   blog generate <stub-name>")
    SUGGESTIONS+=("   blog refine <file>")
fi

if [[ "$CURRENT_DIR" == *"horror"* ]] || [[ "$CURRENT_DIR" == *"stories"* ]] || [[ "$CURRENT_DIR" == *"writing"* ]]; then
    SUGGESTIONS+=("✨ **Creative Dispatcher**: Generate story ideas or packages")
    SUGGESTIONS+=("   creative \"mysterious artifact in lighthouse\"")
    SUGGESTIONS+=("📖 **Narrative Dispatcher**: Analyze story structure")
    SUGGESTIONS+=("   echo \"Three-act structure for horror\" | narrative")
fi

# 2. Git context (if in a git repo)
if git rev-parse --git-dir > /dev/null 2>&1; then
    REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
    CONTEXT+="Git repository: $REPO_NAME\n"

    # Check recent commits
    RECENT_COMMITS=$(git log --oneline -5 2>/dev/null || echo "")
    if [ -n "$RECENT_COMMITS" ]; then
        CONTEXT+="Recent commits:\n$RECENT_COMMITS\n"

        # Analyze commit patterns
        if echo "$RECENT_COMMITS" | grep -qi "fix\|bug\|error\|debug"; then
            SUGGESTIONS+=("🐛 **Tech Dispatcher**: Continue debugging work")
            SUGGESTIONS+=("   cat problematic-file.sh | tech")
        fi

        if echo "$RECENT_COMMITS" | grep -qi "content\|blog\|post\|article"; then
            SUGGESTIONS+=("📄 **Content Dispatcher**: Continue content work")
            SUGGESTIONS+=("   echo \"SEO optimization for latest post\" | content")
        fi
    fi

    # Check for uncommitted changes
    if ! git diff --quiet 2>/dev/null; then
        SUGGESTIONS+=("💾 **Workflow Tip**: You have uncommitted changes")
        SUGGESTIONS+=("   Consider: todo commit <task-num>")
    fi
fi

# 3. Active todo items
if [ -f "$TODO_FILE" ]; then
    TODO_COUNT=$(wc -l < "$TODO_FILE" 2>/dev/null || echo "0")
    CONTEXT+="Active tasks: $TODO_COUNT\n"

    if [ "$TODO_COUNT" -gt 0 ]; then
        # Check for technical tasks
        if grep -qi "debug\|fix\|error\|script\|code" "$TODO_FILE"; then
            SUGGESTIONS+=("🔧 **Todo Integration**: Debug technical tasks")
            SUGGESTIONS+=("   todo debug <num>")
        fi

        # Check for creative tasks
        if grep -qi "story\|write\|creative\|narrative" "$TODO_FILE"; then
            SUGGESTIONS+=("🎨 **Todo Integration**: Delegate creative tasks")
            SUGGESTIONS+=("   todo delegate <num> creative")
        fi

        # Check for content tasks
        if grep -qi "blog\|content\|article\|post" "$TODO_FILE"; then
            SUGGESTIONS+=("📰 **Todo Integration**: Delegate content tasks")
            SUGGESTIONS+=("   todo delegate <num> content")
        fi
    fi
fi

# 4. Recent journal activity
if [ -f "$JOURNAL_FILE" ]; then
    # Get last 3 days of journal entries
    THREE_DAYS_AGO=$(date_shift_days -3 "%Y-%m-%d")
    RECENT_JOURNAL=$(awk -v cutoff="$THREE_DAYS_AGO" '$0 ~ /^\[/ { if ($1 >= "["cutoff) print }' "$JOURNAL_FILE" 2>/dev/null | tail -10)

    if [ -n "$RECENT_JOURNAL" ]; then
        CONTEXT+="Recent journal entries: $(echo "$RECENT_JOURNAL" | wc -l | tr -d ' ')\n"

        # Analyze journal themes
        if echo "$RECENT_JOURNAL" | grep -qi "stress\|overwhelm\|anxious\|stuck"; then
            SUGGESTIONS+=("🏛️  **Stoic Coach**: Work through current challenges")
            SUGGESTIONS+=("   echo \"Feeling overwhelmed by tasks\" | stoic")
        fi

        if echo "$RECENT_JOURNAL" | grep -qi "research\|learn\|study\|notes"; then
            SUGGESTIONS+=("📚 **Research Librarian**: Organize your research")
            SUGGESTIONS+=("   cat research-notes.md | research")
        fi

        # Suggest journal analysis if there's enough data
        JOURNAL_LINES=$(wc -l < "$JOURNAL_FILE" 2>/dev/null || echo "0")
        if [ "$JOURNAL_LINES" -gt 50 ]; then
            SUGGESTIONS+=("📊 **Journal Analysis**: Get insights from your journal")
            SUGGESTIONS+=("   journal analyze  # Last 7 days insights")
            SUGGESTIONS+=("   journal mood     # 14-day sentiment")
            SUGGESTIONS+=("   journal themes   # 30-day patterns")
        fi
    fi
fi

# 5. Time-based suggestions
HOUR=$(date +%H)
if [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 12 ]; then
    SUGGESTIONS+=("🌅 **Morning Routine**: Start your day right")
    SUGGESTIONS+=("   startday  # If you haven't run it yet")
elif [ "$HOUR" -ge 18 ] && [ "$HOUR" -lt 23 ]; then
    SUGGESTIONS+=("🌙 **Evening Routine**: Wrap up your day")
    SUGGESTIONS+=("   goodevening  # Review and backup")
fi

# Display suggestions
echo "📍 **Your Current Context:**"
echo ""
echo -e "$CONTEXT"
echo ""

if [ ${#SUGGESTIONS[@]} -eq 0 ]; then
    echo "💡 **General Suggestions:**"
    echo ""
    echo "No specific context detected. Here are some ways to use AI dispatchers:"
    echo ""
    echo "**Quick Tasks:**"
    echo "  • Debug code: cat script.sh | tech"
    echo "  • Generate ideas: echo \"topic\" | creative"
    echo "  • Get insights: journal analyze"
    echo ""
    echo "**Project Work:**"
    echo "  • Full project planning: dhp-project \"project description\""
    echo "  • Content creation: blog generate <stub>"
    echo "  • Strategic analysis: echo \"challenge\" | strategy"
    echo ""
    echo "**Personal Development:**"
    echo "  • Stoic guidance: echo \"challenge\" | stoic"
    echo "  • Knowledge synthesis: cat notes.md | research"
    echo ""
else
    echo "💡 **Suggested Dispatchers Based on Your Context:**"
    echo ""
    for suggestion in "${SUGGESTIONS[@]}"; do
        echo "  $suggestion"
    done
    echo ""
fi

echo "---"
echo "💡 Run 'cheatsheet' to see all available dispatchers"
echo "📖 Read 'cat ~/dotfiles/bin/README.md' for detailed dispatcher docs"
