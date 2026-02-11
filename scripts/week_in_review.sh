#!/usr/bin/env bash
set -euo pipefail
# week_in_review.sh - Generates a report of your activity over the last week

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE_UTILS="$SCRIPT_DIR/lib/date_utils.sh"
if [ -f "$DATE_UTILS" ]; then
  # shellcheck disable=SC1090
  source "$DATE_UTILS"
else
  echo "Error: date utilities not found at $DATE_UTILS" >&2
  exit 1
fi

if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/lib/common.sh"
fi
if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/lib/config.sh"
else
  echo "Error: configuration library not found at $SCRIPT_DIR/lib/config.sh" >&2
  exit 1
fi

# gawk check removed 
# if ! command -v gawk >/dev/null 2>&1; then
#   echo "Error: gawk is required to run week_in_review." >&2
#   exit 1
# fi

# --- Configuration ---
OUTPUT_FILE=""
if [ "${1:-}" == "--file" ]; then
  WEEK_NUM=$(date +%V)
  YEAR=$(date +%Y)
  REVIEWS_DIR="$HOME/Documents/Reviews/Weekly"
  mkdir -p "$REVIEWS_DIR"
  OUTPUT_FILE="$REVIEWS_DIR/$YEAR-W$WEEK_NUM.md"
fi

TODO_DONE_FILE="${DONE_FILE:?DONE_FILE is not set by config.sh}"
JOURNAL_FILE="${JOURNAL_FILE:?JOURNAL_FILE is not set by config.sh}"
LOOKBACK_DAYS="${REVIEW_LOOKBACK_DAYS:-7}"

for required in "$TODO_DONE_FILE" "$JOURNAL_FILE"; do
  if [ ! -f "$required" ]; then
    echo "Error: Required data file missing: $required" >&2
    exit 1
  fi
done

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
  true > "$OUTPUT_FILE"
fi

output "========================================"
output "    Your Week in Review: $(date +%F)"
output "========================================"

# --- Completed Tasks ---
output "\n## Recently Completed Tasks ##"
TASK_CUTOFF="$(date_shift_days "-$LOOKBACK_DAYS" "%Y-%m-%d")"
awk -F'|' -v cutoff="$TASK_CUTOFF" '
    NF >= 2 {
        date_str = substr($1, 1, 10)
        if (date_str >= cutoff) {
            print
        }
    }
' "$TODO_DONE_FILE" | while read -r line; do output "$line"; done

# --- Journal Entries ---
output "\n## Recent Journal Entries ##"
awk -F'|' -v cutoff="$TASK_CUTOFF" '
    NF >= 2 {
        date_str = substr($1, 1, 10)
        if (date_str >= cutoff) {
            print
        }
    }
' "$JOURNAL_FILE" | while read -r line; do output "$line"; done

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
