#!/usr/bin/env bash
set -euo pipefail

# idea.sh - A simple, powerful command-line idea list manager
#
# Manages aspirational tasks ("ideas") that aren't ready for the todo list.
# Ideas use the same data format as the todo list and can be promoted.
#
# Usage: idea.sh <command> [args]
#
# Commands:
#   add <text>      Add a new idea
#   list            Show all current ideas
#   rm <#idea>      Remove an idea permanently
#   clear           Clear all ideas
#   up              Open idea file in editor
#   to-todo <#idea> Promote an idea to the actionable todo list
#
# Examples:
#   idea.sh add "Learn Rust"
#   idea.sh to-todo 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_lib "config.sh"

# Define Paths
IDEA_FILE="${IDEA_FILE:?IDEA_FILE is not set by config.sh}"
TODO_FILE="${TODO_FILE:?TODO_FILE is not set by config.sh}"

# Ensure data files exist
touch "$IDEA_FILE" "$TODO_FILE"

#=============================================================================
# Helper Functions
#=============================================================================

get_idea_line() {
    local num="$1"
    sed -n "${num}p" "$IDEA_FILE"
}

#=============================================================================
# Subcommand Functions
#=============================================================================

cmd_add() {
    local idea_text="$*"

    if [[ -z "$idea_text" ]]; then
        echo "Usage: $(basename "$0") add <idea>"
        exit "$EXIT_INVALID_ARGS"
    fi

    idea_text=$(sanitize_for_storage "$idea_text")
    
    echo "$(date +%Y-%m-%d)|$idea_text" >> "$IDEA_FILE"

    local messages=(
        "Idea captured!"
        "Great idea, safely stored."
        "Added to the backlog!"
    )
    printf "%s %s\n" "${messages[$((RANDOM % ${#messages[@]}))]}" "$idea_text"
}

cmd_list() {
    echo "--- IDEAS ---"
    if [[ ! -s "$IDEA_FILE" ]]; then
        echo "No ideas found."
        return
    fi
    awk -F'|' '{ printf "%-4s %-12s %s\n", NR, $1, $2 }' "$IDEA_FILE"
}

cmd_rm() {
    local idea_num="${1:-}"
    [[ -n "$idea_num" ]] || die "Usage: $(basename "$0") rm <number>" "$EXIT_INVALID_ARGS"
    validate_numeric "$idea_num" "idea number" || die "Invalid idea number '$idea_num'" "$EXIT_ERROR"

    local idea_line
    idea_line=$(get_idea_line "$idea_num") || die "Unable to read idea $idea_num" "$EXIT_ERROR"
    [[ -n "$idea_line" ]] || die "Idea $idea_num not found" "$EXIT_ERROR"

    # Remove from idea file atomically
    atomic_delete_line "$idea_num" "$IDEA_FILE" || {
        die "Failed to delete idea line $idea_num from idea file" "$EXIT_ERROR"
    }

    echo "Idea $idea_num removed."
}

cmd_clear() {
    # Atomic clear (write empty string)
    atomic_write "" "$IDEA_FILE" || die "Failed to clear idea file" "$EXIT_ERROR"
    echo "All ideas cleared."
}

cmd_to_todo() {
    local idea_num="${1:-}"
    [[ -n "$idea_num" ]] || die "Usage: $(basename "$0") to-todo <number>" "$EXIT_INVALID_ARGS"
    validate_numeric "$idea_num" "idea number" || die "Invalid idea number '$idea_num'" "$EXIT_ERROR"

    local idea_line
    idea_line=$(get_idea_line "$idea_num") || die "Unable to read idea $idea_num" "$EXIT_ERROR"
    [[ -n "$idea_line" ]] || die "Idea $idea_num not found" "$EXIT_ERROR"
    
    # Extract text part
    local idea_text
    idea_text=$(echo "$idea_line" | cut -d'|' -f2-)

    # Append to todo file
    idea_text=$(sanitize_for_storage "$idea_text")
    echo "$(date +%Y-%m-%d)|$idea_text" >> "$TODO_FILE"

    # Remove from idea file atomically
    atomic_delete_line "$idea_num" "$IDEA_FILE" || {
        die "Failed to delete idea line $idea_num from idea file" "$EXIT_ERROR"
    }

    echo "Moved idea to actionable todo: $idea_text"
}

cmd_up() {
    if command -v code >/dev/null 2>&1; then
        code "$IDEA_FILE"
        echo "Opening idea file in VS Code..."
    elif [[ -n "${EDITOR:-}" ]]; then
        "$EDITOR" "$IDEA_FILE"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        open "$IDEA_FILE"
        echo "Opening idea file..."
    else
        echo "No editor found and not on macOS."
    fi
}

#=============================================================================
# Main Dispatcher
#=============================================================================

show_help() {
    cat << EOF
Usage: $(basename "$0") <command> [args]

Idea Management:
  add <text>                  Add a new idea
  list                        Show all current ideas
  rm <#idea>                  Remove an idea permanently
  clear                       Clear all ideas
  up                          Open idea file in editor
  to-todo <#idea>             Promote an idea to the actionable todo list

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
        rm)         cmd_rm "$@" ;;
        clear)      cmd_clear "$@" ;;
        to-todo)    cmd_to_todo "$@" ;;
        up|update)  cmd_up "$@" ;;
        -h|--help|help) show_help ;;
        *)
            echo "Error: Unknown command: $cmd" >&2
            show_help
            log_error "Unknown idea command: $cmd"
            exit "$EXIT_ERROR"
            ;;
    esac
}

main "$@"
