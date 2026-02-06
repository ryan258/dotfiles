#!/usr/bin/env bash
set -euo pipefail

# --- schedule.sh: A user-friendly wrapper for the 'at' command ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/lib/common.sh"
fi

if [ -z "${1:-}" ]; then
  echo "Usage: schedule.sh \"<time>\" [command] [--todo <task>]"
  echo "Example: schedule.sh \"2:30 PM\" \"remind 'Call Mom'\""
  echo "Example: schedule.sh \"tomorrow 9am\" --todo \"Call the doctor\""
  exit 1
fi

TIME=$(sanitize_input "$1")
TIME=${TIME//$'\n'/ }
shift

escape_single_quotes() {
  local input="$1"
  printf "%s" "$input" | sed "s/'/'\"'\"'/g"
}

# Check for --todo flag
if [ "${1:-}" == "--todo" ]; then
  shift
  TASK=$(sanitize_input "$*")
  TASK=${TASK//$'\n'/ }
  if [ -z "$TASK" ]; then
    echo "Error: Please provide a task description for --todo."
    exit 1
  fi
  # Construct the command to add a todo task
  TASK_ESCAPED=$(escape_single_quotes "$TASK")
  COMMAND="\"$SCRIPT_DIR/todo.sh\" add '$TASK_ESCAPED'"
  echo "Scheduling task: '$TASK' at $TIME"
else
  COMMAND=$(sanitize_input "$*")
  COMMAND=${COMMAND//$'\n'/ }
  if [ -z "$COMMAND" ]; then
    echo "Error: Please provide a command to schedule."
    exit 1
  fi
  echo "Scheduling command: '$COMMAND' at $TIME"
fi

# Schedule the command using at
echo "$COMMAND" | at "$TIME"

echo "Command scheduled. Use 'atq' to see the queue."
