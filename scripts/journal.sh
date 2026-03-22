#!/usr/bin/env bash
set -euo pipefail

# --- A quick command-line journal ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_lib "date_utils.sh"
require_lib "config.sh"

JOURNAL_FILE="${JOURNAL_FILE:?JOURNAL_FILE is not set by config.sh}"

# Ensure journal file exists
touch "$JOURNAL_FILE"

# Cleanup
cleanup() {
    # Placeholder for future temp file cleanup
    :
}
trap cleanup EXIT

# --- Main Logic ---

_journal_ai_analysis() {
    local days="$1"
    local title="$2"
    local reviewing_msg="$3"
    local prompt_msg="$4"

    echo "$title"
    echo "$reviewing_msg"
    echo "---"
    echo ""

    # Get entries from last N days
    local cutoff_date
    cutoff_date=$(date_shift_days "-$days" "%Y-%m-%d")
    local recent_entries
    recent_entries=$(awk -F'|' -v cutoff="$cutoff_date" 'NF>=2 { if (substr($1,1,10) >= cutoff) print }' "$JOURNAL_FILE")

    if [ -z "$recent_entries" ]; then
        echo "No journal entries found in the last $days days."
        echo "Add entries with: $(basename "$0") 'your thoughts here'"
        exit 0
    fi

    # Send to Chief of Staff for analysis
    if command -v dhp-strategy.sh &> /dev/null; then
        {
            echo "$prompt_msg"
            echo ""
            echo "Journal entries (last $days days):"
            echo "---"
            echo "$recent_entries"
        } | dhp-strategy.sh
    else
        die "dhp-strategy.sh dispatcher not found. Make sure bin/ is in your PATH" "$EXIT_FILE_NOT_FOUND"
    fi

    echo ""
    echo "✅ Analysis complete"
}

case "${1:-add}" in
  add)
    # Add a new journal entry.
    if [ $# -gt 0 ]; then shift; fi # Removes 'add' if present
    ENTRY="$*"
    if [ -z "$ENTRY" ]; then
        echo "Usage: $(basename "$0") <text>" >&2
        log_error "Missing journal entry text"
        exit "$EXIT_INVALID_ARGS"
    fi
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    ENTRY=$(sanitize_for_storage "$ENTRY")
    printf '%s|%s\n' "$TIMESTAMP" "$ENTRY" >> "$JOURNAL_FILE"
    echo "Entry added to journal."
    ;;

  list)
    # List the last 5 entries.
    if [[ -s "$JOURNAL_FILE" ]]; then
        echo "--- Last 5 Journal Entries ---"
        tail -n 5 "$JOURNAL_FILE"
    else
        echo "Journal is empty. Start by writing an entry!"
    fi
    ;;

  search)
    # Search for a term in the journal.
    shift
    sort_order="recent"
    while [ $# -gt 0 ]; do
      case "$1" in
        --oldest)
          sort_order="oldest"
          shift
          ;;
        --recent)
          sort_order="recent"
          shift
          ;;
        *)
          break
          ;;
      esac
    done

    if [ $# -eq 0 ]; then
        echo "Usage: $(basename "$0") search [--recent|--oldest] <term>" >&2
        log_error "Missing search term"
        exit "$EXIT_INVALID_ARGS"
    fi

    if [[ ! -s "$JOURNAL_FILE" ]]; then
        echo "Journal is empty. Add entries with: $(basename "$0") \"text\""
        exit 0
    fi

    SEARCH_TERM="$*"
    echo "--- Searching for '$SEARCH_TERM' in journal (sorted by $sort_order) ---"

    if [ "$sort_order" = "recent" ]; then
      if command -v tac >/dev/null 2>&1; then
        search_results=$(tac "$JOURNAL_FILE" | grep -i -- "$SEARCH_TERM" || true)
      else
        search_results=$(tail -r "$JOURNAL_FILE" | grep -i -- "$SEARCH_TERM" || true)
      fi
    else
      search_results=$(grep -i -- "$SEARCH_TERM" "$JOURNAL_FILE" || true)
    fi

    if [ -n "$search_results" ]; then
      echo "$search_results"
    else
      echo "No entries found for '$SEARCH_TERM'."
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
    prompt="Please analyze the following journal entries from the past 7 days.
Focus on:
- Emotional patterns and mood trends
- Recurring themes or concerns
- Progress indicators and wins
- Areas that might need attention"
    _journal_ai_analysis 7 "🤖 Analyzing your journal with AI Staff: Chief of Staff" "Reviewing last 7 days of entries..." "$prompt"
    ;;

  mood)
    # AI-powered sentiment analysis
    prompt="Please perform a sentiment/mood analysis on these journal entries.
Provide:
- Overall mood trend (improving/declining/stable)
- Specific emotional patterns detected
- Day-by-day mood summary if helpful
- Suggestions for emotional wellbeing"
    _journal_ai_analysis 14 "🎭 Analyzing mood from recent journal entries" "Reviewing last 14 days..." "$prompt"
    ;;

  themes)
    # AI-powered theme extraction
    prompt="Please identify recurring themes in these journal entries.
Provide:
- Top 3-5 recurring themes or topics
- Patterns in what I'm focused on or worried about
- Themes that appear to be growing vs. fading
- Any connections between themes"
    _journal_ai_analysis 30 "🔍 Extracting recurring themes from journal" "Analyzing last 30 days..." "$prompt"
    ;;

  up|update)
    # Open the journal file in the editor
    if command -v code >/dev/null 2>&1; then
        code "$JOURNAL_FILE"
    elif [ -n "${EDITOR:-}" ]; then
        "$EDITOR" "$JOURNAL_FILE"
    else
        open "$JOURNAL_FILE"
    fi
    echo "Opening journal file..."
    ;;

  *)
    echo "Error: Unknown command '$1'" >&2
    echo "Usage: $(basename "$0") <text>"
    echo "   or: $(basename "$0") {up|list|search|onthisday|analyze|mood|themes}"
    echo ""
    echo "Standard commands:"
    echo "  journal <text>              : Add a quick journal entry"
    echo "  up                          : Open journal file in editor"
    echo "  list                        : Show last 5 entries"
    echo "  search [--recent] <term>    : Search for a term in journal"
    echo "  onthisday                   : Show entries from this day in past years"
    echo ""
    echo "AI-powered commands:"
    echo "  analyze                     : AI analysis of last 7 days (insights & patterns)"
    echo "  mood                        : AI sentiment analysis of last 14 days"
    echo "  themes                      : AI theme extraction from last 30 days"
    log_error "Unknown journal command '$1'"
    exit "$EXIT_INVALID_ARGS"
    ;;
esac
