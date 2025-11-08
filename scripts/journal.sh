#!/bin/bash
set -euo pipefail

# --- A quick command-line journal ---

JOURNAL_FILE="$HOME/.config/dotfiles-data/journal.txt"

# --- Main Logic ---
case "${1:-add}" in
  add)
    # Add a new journal entry.
    shift # Removes 'add' from the arguments
    ENTRY="$*"
    if [ -z "$ENTRY" ]; then
        echo "Usage: journal <text>"
        exit 1
    fi
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    printf '[%s] %s\n' "$TIMESTAMP" "$ENTRY" >> "$JOURNAL_FILE"
    echo "Entry added to journal."
    ;;

  list)
    # List the last 5 entries.
    if [ -f "$JOURNAL_FILE" ]; then
        echo "--- Last 5 Journal Entries ---"
        tail -n 5 "$JOURNAL_FILE"
    else
        echo "Journal is empty. Start by writing an entry!"
    fi
    ;;

  search)
    # Search for a term in the journal.
    shift
    local sort_order="recent" # Default to recent
    if [ "$1" == "--oldest" ]; then
      sort_order="oldest"
      shift
    elif [ "$1" == "--recent" ]; then
      sort_order="recent"
      shift
    fi

    TERM="$*"
    if [ -z "$TERM" ]; then
        echo "Usage: journal search [--recent|--oldest] <term>"
        exit 1
    fi
    echo "--- Searching for '$TERM' in journal (sorted by $sort_order) ---"

    local search_results
    if [ "$sort_order" == "recent" ]; then
      search_results=$(tac "$JOURNAL_FILE" | grep -i "$TERM" || true)
    else
      search_results=$(grep -i "$TERM" "$JOURNAL_FILE" || true)
    fi

    if [ -n "$search_results" ]; then
      echo "$search_results"
    else
      echo "No entries found for '$TERM'."
    fi
    ;;

  onthisday)
    # Show entries from this day in previous years.
    MONTH_DAY=$(date "+%m-%d")
    echo "--- On this day ($MONTH_DAY) ---"
    grep -i "....-$MONTH_DAY" "$JOURNAL_FILE" || echo "No entries found for this day in previous years."
    ;;

  analyze)
    # AI-powered analysis of recent journal entries
    echo "🤖 Analyzing your journal with AI Staff: Chief of Staff"
    echo "Reviewing last 7 days of entries..."
    echo "---"
    echo ""

    # Get entries from last 7 days
    SEVEN_DAYS_AGO=$(date -v-7d "+%Y-%m-%d")
    RECENT_ENTRIES=$(awk -v cutoff="$SEVEN_DAYS_AGO" '$0 ~ /^\[/ { if ($1 >= "["cutoff) print }' "$JOURNAL_FILE")

    if [ -z "$RECENT_ENTRIES" ]; then
        echo "No journal entries found in the last 7 days."
        echo "Add entries with: journal 'your thoughts here'"
        exit 0
    fi

    # Send to Chief of Staff for analysis
    if command -v dhp-strategy.sh &> /dev/null; then
        {
            echo "Please analyze the following journal entries from the past 7 days."
            echo "Focus on:"
            echo "- Emotional patterns and mood trends"
            echo "- Recurring themes or concerns"
            echo "- Progress indicators and wins"
            echo "- Areas that might need attention"
            echo ""
            echo "Journal entries (last 7 days):"
            echo "---"
            echo "$RECENT_ENTRIES"
        } | dhp-strategy.sh
    else
        echo "Error: dhp-strategy.sh dispatcher not found"
        echo "Make sure bin/ is in your PATH"
        exit 1
    fi

    echo ""
    echo "✅ Analysis complete"
    ;;

  mood)
    # AI-powered sentiment analysis
    echo "🎭 Analyzing mood from recent journal entries"
    echo "Reviewing last 14 days..."
    echo "---"
    echo ""

    # Get entries from last 14 days
    FOURTEEN_DAYS_AGO=$(date -v-14d "+%Y-%m-%d")
    RECENT_ENTRIES=$(awk -v cutoff="$FOURTEEN_DAYS_AGO" '$0 ~ /^\[/ { if ($1 >= "["cutoff) print }' "$JOURNAL_FILE")

    if [ -z "$RECENT_ENTRIES" ]; then
        echo "No journal entries found in the last 14 days."
        exit 0
    fi

    # Send to Chief of Staff for mood analysis
    if command -v dhp-strategy.sh &> /dev/null; then
        {
            echo "Please perform a sentiment/mood analysis on these journal entries."
            echo "Provide:"
            echo "- Overall mood trend (improving/declining/stable)"
            echo "- Specific emotional patterns detected"
            echo "- Day-by-day mood summary if helpful"
            echo "- Suggestions for emotional wellbeing"
            echo ""
            echo "Journal entries (last 14 days):"
            echo "---"
            echo "$RECENT_ENTRIES"
        } | dhp-strategy.sh
    else
        echo "Error: dhp-strategy.sh dispatcher not found"
        exit 1
    fi

    echo ""
    echo "✅ Mood analysis complete"
    ;;

  themes)
    # AI-powered theme extraction
    echo "🔍 Extracting recurring themes from journal"
    echo "Analyzing last 30 days..."
    echo "---"
    echo ""

    # Get entries from last 30 days
    THIRTY_DAYS_AGO=$(date -v-30d "+%Y-%m-%d")
    RECENT_ENTRIES=$(awk -v cutoff="$THIRTY_DAYS_AGO" '$0 ~ /^\[/ { if ($1 >= "["cutoff) print }' "$JOURNAL_FILE")

    if [ -z "$RECENT_ENTRIES" ]; then
        echo "No journal entries found in the last 30 days."
        exit 0
    fi

    # Send to Chief of Staff for theme analysis
    if command -v dhp-strategy.sh &> /dev/null; then
        {
            echo "Please identify recurring themes in these journal entries."
            echo "Provide:"
            echo "- Top 3-5 recurring themes or topics"
            echo "- Patterns in what I'm focused on or worried about"
            echo "- Themes that appear to be growing vs. fading"
            echo "- Any connections between themes"
            echo ""
            echo "Journal entries (last 30 days):"
            echo "---"
            echo "$RECENT_ENTRIES"
        } | dhp-strategy.sh
    else
        echo "Error: dhp-strategy.sh dispatcher not found"
        exit 1
    fi

    echo ""
    echo "✅ Theme analysis complete"
    ;;

  *)
    echo "Error: Unknown command '$1'" >&2
    echo "Usage: journal <text>"
    echo "   or: journal {list|search|onthisday|analyze|mood|themes}"
    echo ""
    echo "Standard commands:"
    echo "  journal <text>              : Add a quick journal entry"
    echo "  list                        : Show last 5 entries"
    echo "  search [--recent] <term>    : Search for a term in journal"
    echo "  onthisday                   : Show entries from this day in past years"
    echo ""
    echo "AI-powered commands:"
    echo "  analyze                     : AI analysis of last 7 days (insights & patterns)"
    echo "  mood                        : AI sentiment analysis of last 14 days"
    echo "  themes                      : AI theme extraction from last 30 days"
    exit 1
    ;;
esac
