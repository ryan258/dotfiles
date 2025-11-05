#!/bin/bash
set -euo pipefail
# week_in_review.sh - Generates a report of your activity over the last week

# --- Configuration ---
OUTPUT_FILE=""
if [ "${1:-}" == "--file" ]; then
  WEEK_NUM=$(date +%V)
  YEAR=$(date +%Y)
  REVIEWS_DIR="$HOME/Documents/Reviews/Weekly"
  mkdir -p "$REVIEWS_DIR"
  OUTPUT_FILE="$REVIEWS_DIR/$YEAR-W$WEEK_NUM.md"
fi

# --- Functions ---

# Function to output a string to the console or a file
output() {
  if [ -n "$OUTPUT_FILE" ]; then
    echo -e "$1" >> "$OUTPUT_FILE"
  else
    echo -e "$1"
  fi
}

# --- Main Logic ---

# Clear the output file if it exists
if [ -n "$OUTPUT_FILE" ]; then
  > "$OUTPUT_FILE"
fi

output "========================================"
output "    Your Week in Review: $(date +%F)"
output "========================================"

# --- Completed Tasks ---
TODO_DONE_FILE="$HOME/.config/dotfiles-data/todo_done.txt"
if [ -f "$TODO_DONE_FILE" ]; then
    output "\n## Recently Completed Tasks ##"
    # This looks for tasks completed in the last 7 days
    gawk -v cutoff="$(date -v-7d +%F)" '
        match($0, /\[([0-9]{4}-[0-9]{2}-[0-9]{2})/, m) {
            if (m[1] >= cutoff) {
                print
            }
        }
    ' "$TODO_DONE_FILE" | while read -r line; do output "$line"; done
fi

# --- Journal Entries ---
JOURNAL_FILE="$HOME/.config/dotfiles-data/journal.txt"
if [ -f "$JOURNAL_FILE" ]; then
    output "\n## Recent Journal Entries ##"
    gawk -v cutoff="$(date -v-7d +%F)" '
        match($0, /\[([0-9]{4}-[0-9]{2}-[0-9]{2})/, m) {
            if (m[1] >= cutoff) {
                print
            }
        }
    ' "$JOURNAL_FILE" | while read -r line; do output "$line"; done
fi

# --- Git Contributions (in current project) ---
if [ -d .git ]; then
    MY_NAME=$(git config user.name)
    output "\n## Git Contributions This Week ##"
    git log --oneline --author="$MY_NAME" --since="1 week ago" | while read -r line; do output "$line"; done
fi

output "\n========================================"

if [ -n "$OUTPUT_FILE" ]; then
  echo "Weekly review saved to $OUTPUT_FILE"
fi
