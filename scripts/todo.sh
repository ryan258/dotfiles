#!/usr/bin/env bash
set -euo pipefail

# --- A simple, powerful command-line todo list manager ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_lib "config.sh"

# Define Paths
TODO_FILE="${TODO_FILE:?TODO_FILE is not set by config.sh}"
DONE_FILE="${DONE_FILE:?DONE_FILE is not set by config.sh}"
IDEA_FILE="${IDEA_FILE:?IDEA_FILE is not set by config.sh}"

# Tools
TIME_TRACKER="$SCRIPT_DIR/time_tracker.sh"
SPOON_MANAGER="$SCRIPT_DIR/spoon_manager.sh"

# Ensure data files exist
touch "$TODO_FILE" "$DONE_FILE"

# Setup cleanup trap provided by common.sh/file_ops.sh usually, but we can add specific ones if needed.
# common.sh sources file_ops.sh which defines atomic ops with their own traps.
# Global cleanup for this script? None needed currently as valid temp files are handled by atomic ops.

#=============================================================================
# Subcommand Functions
#=============================================================================

cmd_add() {
    local task_text="$*"

    if [[ -z "$task_text" ]]; then
        echo "Usage: $(basename "$0") add <task>"
        exit 1
    fi

    task_text=$(sanitize_for_storage "$task_text")
    
    # Append to file (simple append is generally safe, or we could use atomic_append if we implemented it)
    echo "$(date +%Y-%m-%d)|$task_text" >> "$TODO_FILE"

    # Encouraging messages
    local messages=(
        "Task added. You've got this! 💪"
        "Captured! One less thing to remember."
        "On the list. Let's get it done!"
    )
    # Fix ANSI color escapes
    printf "%s ' \033[32m%s \033[0m'\n" "${messages[$((RANDOM % ${#messages[@]}))]}" "$task_text"
}

cmd_list() {
    echo "--- TODO ---"
    if [[ ! -s "$TODO_FILE" ]]; then
        echo "No tasks found."
        return
    fi
    awk -F'|' '{ printf "%-4s %-12s %s\n", NR, $1, $2 }' "$TODO_FILE"
}

cmd_done() {
    local task_num="$1"
    validate_numeric "$task_num" "task number" || die "Invalid task number '$task_num'" "$EXIT_ERROR"

    local task_line
    task_line=$(get_todo_line "$task_num") || die "Unable to read task $task_num" "$EXIT_ERROR"
    [[ -n "$task_line" ]] || die "Task $task_num not found" "$EXIT_ERROR"
    
    # Extract text part
    local task_text
    task_text=$(echo "$task_line" | cut -d'|' -f2-)

    # Append to done file (pipe-delimited)
    task_text=$(sanitize_for_storage "$task_text")
    echo "$(date '+%Y-%m-%d %H:%M:%S')|$task_text" >> "$DONE_FILE"

    # Remove from todo file atomically
    atomic_delete_line "$task_num" "$TODO_FILE" || {
        die "Failed to delete task line $task_num from todo file" "$EXIT_ERROR"
    }

    local messages=(
        "Great job! 🎯"
        "Another one bites the dust!"
        "You're on fire! 🔥"
        "Progress! Keep going!"
    )
    printf "%s: ' \033[32m%s \033[0m'\n" "${messages[$((RANDOM % ${#messages[@]}))]}" "$task_text"
}

cmd_rm() {
    local task_num="$1"
    validate_numeric "$task_num" "task number" || die "Invalid task number '$task_num'" "$EXIT_ERROR"

    local task_line
    task_line=$(get_todo_line "$task_num") || die "Unable to read task $task_num" "$EXIT_ERROR"
    [[ -n "$task_line" ]] || die "Task $task_num not found" "$EXIT_ERROR"

    # Remove from todo file atomically
    atomic_delete_line "$task_num" "$TODO_FILE" || {
        die "Failed to delete task line $task_num from todo file" "$EXIT_ERROR"
    }

    echo "Task $task_num removed permanently."
}

cmd_clear() {
    if [[ -s "$TODO_FILE" ]]; then
        # Move all to done
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                task_text=$(echo "$line" | cut -d'|' -f2-)
                task_text=$(sanitize_for_storage "$task_text")
                echo "$(date '+%Y-%m-%d %H:%M:%S')|$task_text" >> "$DONE_FILE"
            fi
        done < "$TODO_FILE"
    fi
    
    # Atomic clear (write empty string)
    atomic_write "" "$TODO_FILE" || die "Failed to clear todo file" "$EXIT_ERROR"
    echo "All tasks cleared."
}

cmd_bump() {
    local task_num="$1"
    validate_numeric "$task_num" "task number" || die "Invalid task number '$task_num'" "$EXIT_ERROR"

    local task_line
    task_line=$(get_todo_line "$task_num") || die "Unable to read task $task_num" "$EXIT_ERROR"
    [[ -n "$task_line" ]] || die "Task $task_num not found" "$EXIT_ERROR"

    # Delete then prepend
    atomic_delete_line "$task_num" "$TODO_FILE" || die "Failed to remove task $task_num before bump" "$EXIT_ERROR"
    atomic_prepend "$task_line" "$TODO_FILE" || die "Failed to bump task $task_num to top" "$EXIT_ERROR"

    echo "Bumped task $task_num to top."
}

cmd_to_idea() {
    local task_num="${1:-}"
    [[ -n "$task_num" ]] || die "Usage: $(basename "$0") to-idea <number>" "$EXIT_INVALID_ARGS"
    validate_numeric "$task_num" "task number" || die "Invalid task number '$task_num'" "$EXIT_ERROR"

    local task_line
    task_line=$(get_todo_line "$task_num") || die "Unable to read task $task_num" "$EXIT_ERROR"
    [[ -n "$task_line" ]] || die "Task $task_num not found" "$EXIT_ERROR"

    # Extract text part
    local task_text
    task_text=$(echo "$task_line" | cut -d'|' -f2-)

    # Append to idea file
    task_text=$(sanitize_for_storage "$task_text")
    echo "$(date +%Y-%m-%d)|$task_text" >> "$IDEA_FILE"

    # Remove from todo file atomically
    atomic_delete_line "$task_num" "$TODO_FILE" || {
        die "Failed to delete task line $task_num from todo file" "$EXIT_ERROR"
    }

    echo "Moved task $task_num to ideas list: $task_text"
}

cmd_top() {
    local count="${1:-3}"
    validate_numeric "$count" "count" || count=3
    
    echo "--- Top $count Tasks ---"
    if [[ ! -s "$TODO_FILE" ]]; then
        return
    fi
    head -n "$count" "$TODO_FILE" | awk -F'|' '{ printf "%-4s %-12s %s\n", NR, $1, $2 }'
}

cmd_commit() {
    local task_num="$1"
    shift
    local msg="$*"

    validate_numeric "$task_num" "task number" || die "Invalid task number '$task_num'" "$EXIT_ERROR"

    local task_line
    task_line=$(get_todo_line "$task_num") || die "Unable to read task $task_num" "$EXIT_ERROR"
    [[ -n "$task_line" ]] || die "Task $task_num not found" "$EXIT_ERROR"
    local task_text
    task_text=$(echo "$task_line" | cut -d'|' -f2-)

    if [[ -z "$msg" ]]; then
        msg="Done: $task_text"
    fi

    # Run git commit
    git add .
    git commit -m "$msg"

    # Mark as done
    cmd_done "$task_num"
    echo "Completed and committed: $task_text"
}

cmd_undo() {
    if [[ ! -s "$DONE_FILE" ]]; then
        echo "No tasks to undo."
        exit "$EXIT_ERROR"
    fi

    local last_done_task
    last_done_task=$(tail -n 1 "$DONE_FILE")
    
    # Remove from done file (using legacy sed -i because done file can be huge and atomic_delete implies rewriting whole file... 
    # but wait, atomic_delete IS safer. Let's use atomic operations as mandated.)
    # line count of done file? if large, this is slow.
    # But for correctness:
    # We replace strict line deletion with: read all but last line to temp?
    # Actually atomic_delete_line takes a line number.
    # We need to know line number of last line.
    local last_line_num
    last_line_num=$(wc -l < "$DONE_FILE" | tr -d ' ')
    atomic_delete_line "$last_line_num" "$DONE_FILE" || die "Failed to update done-file while undoing last task" "$EXIT_ERROR"

    # Extract original text (field after timestamp)
    local task_text_to_restore
    task_text_to_restore=$(echo "$last_done_task" | cut -d'|' -f2-)

    # Add back to todo
    echo "$(date +%Y-%m-%d)|$task_text_to_restore" >> "$TODO_FILE"
    echo "Restored task: $task_text_to_restore"
}

# Wrapper for time_tracker.sh
cmd_time_wrapper() {
    local cmd="$1"
    shift
    
    if [[ ! -x "$TIME_TRACKER" ]]; then
        die "Time tracker script not found at $TIME_TRACKER" "$EXIT_FILE_NOT_FOUND"
    fi
    "$TIME_TRACKER" "$cmd" "$@"
}

cmd_start() {
    local task_num="$1"
    validate_numeric "$task_num" "task number" || die "Invalid task number '$task_num'" "$EXIT_ERROR"
    
    local task_text
    if ! task_text=$(get_todo_text "$task_num"); then
        die "Unable to read task $task_num" "$EXIT_ERROR"
    fi
    if [[ -z "$task_text" ]]; then
        die "Task $task_num not found" "$EXIT_ERROR"
    fi
    
    cmd_time_wrapper "start" "$task_num" "$task_text"
}

cmd_stop() {
    cmd_time_wrapper "stop"
}

cmd_time() {
    local task_num="$1"
    validate_numeric "$task_num" "task number" || die "Invalid task number '$task_num'" "$EXIT_ERROR"
    cmd_time_wrapper "check" "$task_num"
}

cmd_spend() {
    local task_num="$1"
    local count="$2"
    
    validate_numeric "$task_num" "task id" || die "Invalid task id '$task_num'" "$EXIT_ERROR"
    validate_numeric "$count" "spoon count" || die "Invalid spoon count '$count'" "$EXIT_ERROR"
    
    local task_text
    if ! task_text=$(get_todo_text "$task_num"); then
        die "Unable to read task $task_num" "$EXIT_ERROR"
    fi
    if [[ -z "$task_text" ]]; then
        die "Task $task_num not found" "$EXIT_ERROR"
    fi
    
    if [[ ! -x "$SPOON_MANAGER" ]]; then
        die "Spoon manager not found at $SPOON_MANAGER" "$EXIT_FILE_NOT_FOUND"
    fi
    
    "$SPOON_MANAGER" spend "$count" "$task_text"
}

cmd_up() {
    if command -v code >/dev/null 2>&1; then
        code "$TODO_FILE"
        echo "Opening todo file in VS Code..."
    elif [[ -n "${EDITOR:-}" ]]; then
        "$EDITOR" "$TODO_FILE"
    else
        open "$TODO_FILE"
        echo "Opening todo file..."
    fi
}

cmd_debug() {
    local task_num="$1"
    validate_numeric "$task_num" "task number" || die "Invalid task number '$task_num'" "$EXIT_ERROR"
    
    local task_text
    if ! task_text=$(get_todo_text "$task_num"); then
        die "Unable to read task $task_num" "$EXIT_ERROR"
    fi
    if [[ -z "$task_text" ]]; then
        die "Task $task_num not found" "$EXIT_ERROR"
    fi
    
    echo "🤖 Debugging task #$task_num with AI Staff..."
    echo "Task: $task_text"
    echo "---"
    echo ""

    if echo "$task_text" | grep -qi "debug\|fix\|error\|bug"; then
        # Try to extract a script name
        local script_name
        script_name=$(echo "$task_text" | grep -oE '[a-zA-Z0-9_-]+\.sh' | head -1 || true)

        if [[ -n "$script_name" ]] && [[ -f "$script_name" ]]; then
            echo "Found script: $script_name"
            echo "Sending to AI Staff: Technical Debugging Specialist..."
            cat "$script_name" | dhp-tech.sh
        elif [[ -n "$script_name" ]] && [[ -f "$HOME/dotfiles/scripts/$script_name" ]]; then
            echo "Found script: ~/dotfiles/scripts/$script_name"
            echo "Sending to AI Staff: Technical Debugging Specialist..."
            cat "$HOME/dotfiles/scripts/$script_name" | dhp-tech.sh
        else
            echo "No script file found. Analyzing task description..."
            echo "$task_text" | dhp-tech.sh
        fi
    else
        echo "$task_text" | dhp-tech.sh
    fi
}

cmd_delegate() {
    local task_num="$1"
    local dispatcher="$2"
    
    validate_numeric "$task_num" "task number" || die "Invalid task number '$task_num'" "$EXIT_ERROR"
    [[ -z "$dispatcher" ]] && die "Dispatcher required (tech|creative|content)" "$EXIT_ERROR"

    local task_text
    if ! task_text=$(get_todo_text "$task_num"); then
        die "Unable to read task $task_num" "$EXIT_ERROR"
    fi
    if [[ -z "$task_text" ]]; then
        die "Task $task_num not found" "$EXIT_ERROR"
    fi

    echo "🤖 Delegating task #$task_num to AI Staff ($dispatcher dispatcher)..."
    echo "Task: $task_text"
    echo "---"
    echo ""

    case "$dispatcher" in
        tech|dhp-tech)
            echo "Routing to: Technical Debugging Specialist"
            echo "$task_text" | dhp-tech.sh
            ;;
        creative|dhp-creative)
            echo "Routing to: Creative Writing Team"
            dhp-creative.sh "$task_text"
            ;;
        content|dhp-content)
            echo "Routing to: Content Strategy Team"
            dhp-content.sh "$task_text"
            ;;
        *)
            echo "Error: Unknown dispatcher '$dispatcher'" >&2
            echo "Available: tech, creative, content" >&2
            log_error "Unknown dispatcher '$dispatcher'"
            exit "$EXIT_ERROR"
            ;;
    esac

    echo ""
    echo "✅ Task delegated successfully"
    echo "Review the AI's output above, then mark complete when done:"
    echo "  $(basename "$0") done $task_num"
}

#=============================================================================
# Main Dispatcher
#=============================================================================

show_help() {
    cat << EOF
Usage: $(basename "$0") <command> [args]

Task Management:
  add <text>                  Add a new task
  list                        Show all current tasks
  done <#task>                Mark a task as complete
  rm <#task>                  Remove a task properly (no archive)
  clear                       Clear all tasks
  undo                        Restore the most recently completed task
  up                          Open todo file in editor
  to-idea <#task>             Move a task back to the ideas list

Prioritization:
  bump <#task>                Move a task to the top of the list
  top [count]                 Show the top N tasks (default: 3)

Git Integration:
  commit <#task> [msg]        Commit and mark a task as done

Time & Energy:
  start <#task>               Start timer for task
  stop                        Stop active timer
  time <#task>                Show total time for task
  spend <#task> <count>       Spend spoons on a task

AI-Powered:
  debug <#task>               Debug a task using AI technical specialist
  delegate <#task> <type>     Delegate task to AI (tech|creative|content)
EOF
}

main() {
    local cmd="${1:-list}"
    if [[ "$cmd" != "list" ]]; then
        shift || true
    fi

    case "$cmd" in
        add)        cmd_add "$@" ;;
        list)       cmd_list "$@" ;;
        done)       cmd_done "$@" ;;
        rm)         cmd_rm "$@" ;;
        clear)      cmd_clear "$@" ;;
        undo)       cmd_undo "$@" ;;
        bump)       cmd_bump "$@" ;;
        top)        cmd_top "$@" ;;
        to-idea)    cmd_to_idea "$@" ;;
        commit)     cmd_commit "$@" ;;
        start)      cmd_start "$@" ;;
        stop)       cmd_stop "$@" ;;
        time)       cmd_time "$@" ;;
        spend)      cmd_spend "$@" ;;
        up|update)  cmd_up "$@" ;;
        debug)      cmd_debug "$@" ;;
        delegate)   cmd_delegate "$@" ;;
        -h|--help|help) show_help ;;
        *)
            echo "Error: Unknown command: $cmd" >&2
            show_help
            log_error "Unknown todo command: $cmd"
            exit "$EXIT_ERROR"
            ;;
    esac
}

main "$@"
