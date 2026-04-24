#!/usr/bin/env bash
set -euo pipefail
# week_in_review.sh - Generates a report of your activity over the last week

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_LIB="$SCRIPT_DIR/lib/common.sh"
if [ -f "$COMMON_LIB" ]; then
  # shellcheck disable=SC1090
  source "$COMMON_LIB"
else
  echo "Error: common utilities not found at $COMMON_LIB" >&2
  exit 1
fi

CONFIG_LIB="$SCRIPT_DIR/lib/config.sh"
if [ -f "$CONFIG_LIB" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG_LIB"
else
  echo "Error: configuration library not found at $CONFIG_LIB" >&2
  exit 1
fi

DATE_UTILS="$SCRIPT_DIR/lib/date_utils.sh"
if [ -f "$DATE_UTILS" ]; then
  # shellcheck disable=SC1090
  source "$DATE_UTILS"
else
  echo "Error: date utilities not found at $DATE_UTILS" >&2
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
  WEEK_NUM=$(date_now "%V")
  YEAR=$(date_now "%Y")
  REVIEWS_DIR="$WEEKLY_REVIEW_DIR"
  mkdir -p "$REVIEWS_DIR"
  OUTPUT_FILE="$REVIEWS_DIR/$YEAR-W$WEEK_NUM.md"
fi

TODO_DONE_FILE="${DONE_FILE:?DONE_FILE is not set by config.sh}"
JOURNAL_FILE="${JOURNAL_FILE:?JOURNAL_FILE is not set by config.sh}"
LOOKBACK_DAYS="${REVIEW_LOOKBACK_DAYS:?REVIEW_LOOKBACK_DAYS is not set by config.sh}"
if ! [[ "$LOOKBACK_DAYS" =~ ^[0-9]+$ ]] || [ "$LOOKBACK_DAYS" -lt 1 ]; then
  echo "Error: REVIEW_LOOKBACK_DAYS must be a positive integer, got '$LOOKBACK_DAYS'" >&2
  exit 2
fi

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
while IFS= read -r line; do
  output "$line"
done < <(
  awk -F'|' -v cutoff="$TASK_CUTOFF" '
      NF >= 2 {
          date_str = substr($1, 1, 10)
          if (date_str >= cutoff) {
              print
          }
      }
  ' "$TODO_DONE_FILE"
)

# --- Journal Entries ---
output "\n## Recent Journal Entries ##"
while IFS= read -r line; do
  output "$line"
done < <(
  awk -F'|' -v cutoff="$TASK_CUTOFF" '
      NF >= 2 {
          date_str = substr($1, 1, 10)
          if (date_str >= cutoff) {
              print
          }
      }
  ' "$JOURNAL_FILE"
)

# --- Git Contributions (in current project) ---
if [ -d .git ]; then
    MY_NAME=$(git config user.name || true)
    output "\n## Git Contributions This Week ##"
    while IFS= read -r line; do
      output "$line"
    done < <(git log --oneline --author="$MY_NAME" --since="1 week ago" || true)
fi

output "\n========================================"

if [ -n "$OUTPUT_FILE" ]; then
  echo "Weekly review saved to $OUTPUT_FILE"
fi
