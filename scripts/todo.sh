#!/bin/bash
set -euo pipefail

# --- A simple, powerful command-line todo list manager ---

DATA_DIR="$HOME/.config/dotfiles-data"
TODO_FILE="$DATA_DIR/todo.txt"
DONE_FILE="$DATA_DIR/todo_done.txt"

# Ensure data files exist
touch "$TODO_FILE" "$DONE_FILE"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TIME_TRACKER="$SCRIPT_DIR/time_tracker.sh"

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

  start)
    # Start timer for a task
    if [ -z "${2:-}" ]; then
        echo "Error: Task ID required" >&2
        exit 1
    fi
    # Validate Task ID is numeric
    if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: Task ID must be a number" >&2
        exit 1
    fi

    # Get task text for context
    task_num="$2"
    task_line=$(sed -n "${task_num}p" "$TODO_FILE")
    task_text=$(echo "$task_line" | cut -d'|' -f2-)
    
    if [ -z "$task_text" ]; then
         echo "Error: Task $task_num not found" >&2
         exit 1
    fi
    
    "$TIME_TRACKER" start "$task_num" "$task_text"
    ;;
    
  stop)
    # Stop active timer
    "$TIME_TRACKER" stop
    ;;
    
  time)
    # Check time for a task
    if [ -z "${2:-}" ]; then
        echo "Error: Task ID required" >&2
        exit 1
    fi
    # Validate Task ID is numeric
    if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: Task ID must be a number" >&2
        exit 1
    fi
    "$TIME_TRACKER" check "$2"
    ;;


  spend)
    # Spend spoons on a task
    if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
        echo "Error: Task ID and Spoon Count required" >&2
        echo "Usage: $0 spend <task_id> <count>" >&2
        exit 1
    fi
    # Validate inputs are numeric
    if ! [[ "${2:-}" =~ ^[0-9]+$ ]] || ! [[ "${3:-}" =~ ^[0-9]+$ ]]; then
        echo "Error: Task ID and Spoon Count must be numbers" >&2
        exit 1
    fi
    task_num="$2"
    
    # Get task text
    task_line=$(sed -n "${task_num}p" "$TODO_FILE")
    task_text=$(echo "$task_line" | cut -d'|' -f2-)
    
    if [ -z "$task_text" ]; then
         echo "Error: Task $task_num not found" >&2
         exit 1
    fi
    
    # Call spoon manager
    SPOON_MANAGER="$SCRIPT_DIR/spoon_manager.sh"
    if [ -x "$SPOON_MANAGER" ]; then
        "$SPOON_MANAGER" spend "$3" "$task_text"
    else
        echo "Error: Spoon manager not found" >&2
        exit 1
    fi
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
    sed -i.bak "${task_num}d" "$TODO_FILE"
    
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
    sed -i.bak "${task_num}d" "$TODO_FILE"
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
    sed -i.bak "${task_num}d" "$TODO_FILE"
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
    sed -i.bak '$d' "$DONE_FILE"
    # Extract original task text, removing the timestamp
    task_text_to_restore=$(echo "$last_done_task" | sed -E 's/^\[[0-9- :]+] //')
    # Add it back to the todo list with a new date
    echo "$(date +%Y-%m-%d)|$task_text_to_restore" >> "$TODO_FILE"
    echo "Restored task: $task_text_to_restore"
    ;;

  debug)
    # Debug a task using AI (dhp-tech dispatcher)
    task_num=$2
    if [ -z "$task_num" ]; then
        echo "Usage: $0 debug <task_number>"
        echo "Example: $0 debug 3"
        exit 1
    fi

    # Get the task text
    task_line=$(sed -n "${task_num}p" "$TODO_FILE")
    task_text=$(echo "$task_line" | cut -d'|' -f2-)

    if [ -z "$task_text" ]; then
        echo "Error: Task $task_num not found."
        exit 1
    fi

    echo "🤖 Debugging task #$task_num with AI Staff..."
    echo "Task: $task_text"
    echo "---"
    echo ""

    # Check if this looks like a script debugging task
    if echo "$task_text" | grep -qi "debug\|fix\|error\|bug"; then
        # Try to extract a script name from the task
        script_name=$(echo "$task_text" | grep -oE '[a-zA-Z0-9_-]+\.sh' | head -1)

        if [ -n "$script_name" ] && [ -f "$script_name" ]; then
            echo "Found script: $script_name"
            echo "Sending to AI Staff: Technical Debugging Specialist..."
            echo ""
            cat "$script_name" | dhp-tech.sh
        elif [ -n "$script_name" ] && [ -f "$HOME/dotfiles/scripts/$script_name" ]; then
            echo "Found script: ~/dotfiles/scripts/$script_name"
            echo "Sending to AI Staff: Technical Debugging Specialist..."
            echo ""
            cat "$HOME/dotfiles/scripts/$script_name" | dhp-tech.sh
        else
            # No script found, send task description for general help
            echo "No script file found. Analyzing task description..."
            echo ""
            echo "$task_text" | dhp-tech.sh
        fi
    else
        # Not a debugging task, send for general analysis
        echo "$task_text" | dhp-tech.sh
    fi
    ;;

  delegate)
    # Delegate a task to an AI dispatcher
    task_num=$2
    dispatcher=$3

    if [ -z "$task_num" ] || [ -z "$dispatcher" ]; then
        echo "Usage: $0 delegate <task_number> <dispatcher>"
        echo ""
        echo "Available dispatchers:"
        echo "  tech      - Technical debugging and code analysis"
        echo "  creative  - Creative writing and storytelling"
        echo "  content   - SEO-optimized content creation"
        echo ""
        echo "Example: $0 delegate 3 creative"
        exit 1
    fi

    # Get the task text
    task_line=$(sed -n "${task_num}p" "$TODO_FILE")
    task_text=$(echo "$task_line" | cut -d'|' -f2-)

    if [ -z "$task_text" ]; then
        echo "Error: Task $task_num not found."
        exit 1
    fi

    echo "🤖 Delegating task #$task_num to AI Staff ($dispatcher dispatcher)..."
    echo "Task: $task_text"
    echo "---"
    echo ""

    # Route to the appropriate dispatcher
    case "$dispatcher" in
        tech|dhp-tech)
            echo "Routing to: Technical Debugging Specialist"
            echo ""
            echo "$task_text" | dhp-tech.sh
            ;;
        creative|dhp-creative)
            echo "Routing to: Creative Writing Team"
            echo ""
            dhp-creative.sh "$task_text"
            ;;
        content|dhp-content)
            echo "Routing to: Content Strategy Team"
            echo ""
            dhp-content.sh "$task_text"
            ;;
        *)
            echo "Error: Unknown dispatcher '$dispatcher'"
            echo "Available: tech, creative, content"
            exit 1
            ;;
    esac

    echo ""
    echo "✅ Task delegated successfully"
    echo "Review the AI's output above, then mark complete when done:"
    echo "  todo done $task_num"
    ;;

  *)
    echo "Error: Unknown command '$1'" >&2
    echo "Usage: $0 {add|list|done|clear|commit|bump|top|undo|debug|delegate|start|stop|time}"
    echo ""
    echo "Task Management:"
    echo "  add <'task text'>           : Add a new task"
    echo "  list                        : Show all current tasks"
    echo "  done <task_number>          : Mark a task as complete"
    echo "  clear                       : Clear all tasks"
    echo "  undo                        : Restore the most recently completed task"
    echo ""
    echo "Prioritization:"
    echo "  bump <task_number>          : Move a task to the top of the list"
    echo "  top [count]                 : Show the top N tasks (default: 3)"
    echo ""
    echo "Git Integration:"
    echo "  commit <task_number> ['msg']: Commit and mark a task as done"
    echo ""
    echo "AI-Powered Commands:"
    echo "  debug <task_number>         : Debug a task using AI technical specialist"
    echo "  delegate <task_num> <type>  : Delegate task to AI (tech|creative|content)"
    echo ""
    echo "Time Tracking:"
    echo "  start <task_number>         : Start timer for task"
    echo "  stop                        : Stop active timer"
    echo "  time <task_number>          : Show total time for task"
    echo ""
    echo "Energy Management:"
    echo "  spend <task_id> <count>     : Spend spoons on a task"
    exit 1
    ;;
esac
