#!/bin/bash
set -euo pipefail

# --- A quick command-line journal ---
# Usage:
#   journal.sh This is my entry for the evening.
#   journal.sh (with no text, to read the last 5 entries)

JOURNAL_FILE="$HOME/.config/dotfiles-data/journal.txt"
ENTRY="$*" # Combine all arguments into a single entry

# If the entry is empty, show the last 5 lines of the journal
if [ -z "$ENTRY" ]; then
    if [ -f "$JOURNAL_FILE" ]; then
        echo "--- Last 5 Journal Entries ---"
        tail -n 5 "$JOURNAL_FILE"
    else
        echo "Journal is empty. Start by writing an entry!"
    fi
    exit 0
fi

# Get the current date and time
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Append the timestamp and the entry to your journal file
printf '[%s] %s\n' "$TIMESTAMP" "$ENTRY" >> "$JOURNAL_FILE"

echo "Entry added to journal."
