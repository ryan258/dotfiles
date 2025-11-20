#!/bin/bash
set -euo pipefail

# --- schedule.sh: A user-friendly wrapper for the 'at' command ---

if [ -z "$1" ]; then
  echo "Usage: schedule.sh \"<time>\" [command] [--todo <task>]"
  echo "Example: schedule.sh \"2:30 PM\" \"remind 'Call Mom'\""
  echo "Example: schedule.sh \"tomorrow 9am\" --todo \"Call the doctor\""
  exit 1
fi

TIME="$1"
shift

# Check for --todo flag
if [ "$1" == "--todo" ]; then
  shift
  TASK="$*"
  if [ -z "$TASK" ]; then
    echo "Error: Please provide a task description for --todo."
    exit 1
  fi
  # Construct the command to add a todo task
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  COMMAND="$SCRIPT_DIR/todo.sh add '$TASK'"
  echo "Scheduling task: '$TASK' at $TIME"
else
  COMMAND="$*"
  if [ -z "$COMMAND" ]; then
    echo "Error: Please provide a command to schedule."
    exit 1
  fi
  echo "Scheduling command: '$COMMAND' at $TIME"
fi

# Schedule the command using at
echo "$COMMAND" | at "$TIME"

echo "Command scheduled. Use 'atq' to see the queue."
