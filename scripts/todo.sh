#!/bin/bash
set -euo pipefail

# --- A simple, powerful command-line todo list manager ---

DATA_DIR="$HOME/.config/dotfiles-data"
TODO_FILE="$DATA_DIR/todo.txt"
DONE_FILE="$DATA_DIR/todo_done.txt"

# Ensure data files exist
touch "$TODO_FILE" "$DONE_FILE"

# --- Main Logic ---
case "$1" in
  add)
    # Add a new task. Example: todo.sh add "Water the plants"
    shift # Removes 'add' from the arguments
    task_text="$*"
    if [ -z "$task_text" ]; then
        echo "Usage: $0 add <task>"
        exit 1
    fi
    printf '%s\n' "$task_text" >> "$TODO_FILE"
    printf "Added: '%s'\n" "$task_text"
    ;;

  list)
    # List all current tasks with line numbers
    echo "--- TODO ---"
    cat -n "$TODO_FILE"
    ;;

  done)
    # Mark a task as done. Example: todo.sh done 3
    task_num=$2
    if [ -z "$task_num" ]; then
        echo "Error: Please specify the task number to complete."
        echo "Usage: $0 done <task_number>"
        exit 1
    fi
    # Get the text of the completed task
    task_text=$(sed -n "${task_num}p" "$TODO_FILE")
    # Add it to the done file with a timestamp
    if [ -n "$task_text" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $task_text" >> "$DONE_FILE"
    fi
    # Remove it from the todo file
    sed -i '' "${task_num}d" "$TODO_FILE"
    echo "Completed: $task_text"
    ;;

  clear)
    # Moves remaining tasks to the done file with a timestamp and clears the list
    if [ -s "$TODO_FILE" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $line" >> "$DONE_FILE"
        done < "$TODO_FILE"
    fi
    : > "$TODO_FILE"
    echo "All tasks cleared."
    ;;

  *)
    echo "Usage: $0 {add|list|done|clear}"
    echo "  add <'task text'> : Add a new task"
    echo "  list                : Show all current tasks"
    echo "  done <task_number>  : Mark a task as complete"
    echo "  clear               : Clear all tasks"
    ;;
esac
