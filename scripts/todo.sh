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
    # Strip pipe characters to prevent parsing issues
    task_text=$(echo "$task_text" | tr -d '|')
    echo "$(date +%Y-%m-%d)|$task_text" >> "$TODO_FILE"
    
    # Encouraging messages for adding a task
    add_messages=(
        "Task added. You've got this! 💪"
        "Captured! One less thing to remember."
        "On the list. Let's get it done!"
    )
    printf "%s\n" "${add_messages[$((RANDOM % ${#add_messages[@]}))]} '[32m%s[0m'" "$task_text"
    ;;

  list)
    # List all current tasks with line numbers
    echo "--- TODO ---"
    awk -F'|' '{ printf "%-4s %-12s %s\n", NR, $1, $2 }' "$TODO_FILE"
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
    task_line=$(sed -n "${task_num}p" "$TODO_FILE")
    task_text=$(echo "$task_line" | cut -d'|' -f2-)
    # Add it to the done file with a timestamp
    if [ -n "$task_text" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $task_text" >> "$DONE_FILE"
    fi
    # Remove it from the todo file
    sed -i '' "${task_num}d" "$TODO_FILE"
    
    # Encouraging messages for completing a task
    done_messages=(
        "Great job! 🎯"
        "Another one bites the dust!"
        "You're on fire! 🔥"
        "Progress! Keep going!"
    )
    printf "%s: '[32m%s[0m'\n" "${done_messages[$((RANDOM % ${#done_messages[@]}))]} " "$task_text"
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

  commit)
    # Commit and mark a task as done.
    if [ -z "$2" ]; then
        echo "Usage: $0 commit <task_number> [commit_message]"
        exit 1
    fi
    task_num="$2"
    shift 2
    commit_message="$*"

    # Get the text of the task
    task_line=$(sed -n "${task_num}p" "$TODO_FILE")
    task_text=$(echo "$task_line" | cut -d'|' -f2-)

    if [ -z "$task_text" ]; then
        echo "Error: Task $task_num not found."
        exit 1
    fi

    # If no commit message is provided, use the task text.
    if [ -z "$commit_message" ]; then
        commit_message="Done: $task_text"
    fi

    # Run git commit
    git add .
    git commit -m "$commit_message"

    # Mark task as done
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $task_text" >> "$DONE_FILE"
    sed -i '' "${task_num}d" "$TODO_FILE"
    echo "Completed and committed: $task_text"
    ;;

  bump)
    # Move a task to the top of the list.
    if [ -z "$2" ]; then
        echo "Usage: $0 bump <task_number>"
        exit 1
    fi
    task_num="$2"
    task_line=$(sed -n "${task_num}p" "$TODO_FILE")
    if [ -z "$task_line" ]; then
        echo "Error: Task $task_num not found."
        exit 1
    fi
    sed -i '' "${task_num}d" "$TODO_FILE"
    echo "$task_line" | cat - "$TODO_FILE" > temp && mv temp "$TODO_FILE"
    echo "Bumped task $task_num to the top."
    ;;

  top)
    # Show the top N tasks.
    count="${2:-3}"
    echo "--- Top $count Tasks ---"
    head -n "$count" "$TODO_FILE" | awk -F'|' '{ printf "%-4s %-12s %s\n", NR, $1, $2 }'
    ;;

  undo)
    # Restore the most recently completed task.
    if [ ! -s "$DONE_FILE" ]; then
        echo "No tasks to undo."
        exit 1
    fi
    # Get the last completed task
    last_done_task=$(tail -n 1 "$DONE_FILE")
    # Remove it from the done file
    sed -i '' '$d' "$DONE_FILE"
    # Extract original task text, removing the timestamp
    task_text_to_restore=$(echo "$last_done_task" | sed -E 's/^\[[0-9- :]+] //')
    # Add it back to the todo list with a new date
    echo "$(date +%Y-%m-%d)|$task_text_to_restore" >> "$TODO_FILE"
    echo "Restored task: $task_text_to_restore"
    ;;

  *)
    echo "Error: Unknown command '$1'" >&2
    echo "Usage: $0 {add|list|done|clear|commit|bump|top|undo}"
    echo "  add <'task text'> : Add a new task"
    echo "  list                : Show all current tasks"
    echo "  done <task_number>  : Mark a task as complete"
    echo "  clear               : Clear all tasks"
    echo "  commit <task_number> ['message'] : Commit and mark a task as done"
    echo "  bump <task_number>  : Move a task to the top of the list"
    echo "  top [count]         : Show the top N tasks (default: 3)"
    echo "  undo                : Restore the most recently completed task"
    exit 1
    ;;
esac
