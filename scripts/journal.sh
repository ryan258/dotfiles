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
    TERM="$*"
    if [ -z "$TERM" ]; then
        echo "Usage: journal search <term>"
        exit 1
    fi
    echo "--- Searching for '$TERM' in journal ---"
    grep -i "$TERM" "$JOURNAL_FILE" || echo "No entries found for '$TERM'."
    ;;

  onthisday)
    # Show entries from this day in previous years.
    MONTH_DAY=$(date "+%m-%d")
    echo "--- On this day ($MONTH_DAY) ---"
    grep -i "....-$MONTH_DAY" "$JOURNAL_FILE" || echo "No entries found for this day in previous years."
    ;;

  *)
    echo "Error: Unknown command '$1'" >&2
    echo "Usage: journal <text>"
    echo "   or: journal {list|search|onthisday}"
    exit 1
    ;;
esac
