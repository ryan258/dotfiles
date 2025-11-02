#!/bin/bash
set -euo pipefail

# --- schedule.sh: A user-friendly wrapper for the 'at' command ---

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: schedule.sh \"<time>\" \"<command>\""
  echo "Example: schedule.sh \"2:30 PM\" \"remind 'Call Mom'\""
  exit 1
fi

TIME="$1"
COMMAND="$2"

echo "Scheduling command: '$COMMAND' at $TIME"

echo "$COMMAND" | at "$TIME"

echo "Command scheduled. Use 'atq' to see the queue."
