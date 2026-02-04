#!/usr/bin/env bash

# scripts/time_tracker.sh
# CLI Wrapper for time tracking functionality
# Log Format (time_tracking.txt):
# START|task_id|description|timestamp (YYYY-MM-DD HH:MM:SS)
# STOP|task_id|timestamp (YYYY-MM-DD HH:MM:SS)

set -euo pipefail

# Source the shared library
source "$(dirname "${BASH_SOURCE[0]}")/lib/time_tracking.sh"

show_help() {
    echo "Usage: $(basename "$0") {start|stop|status|report}"
    echo ""
    echo "Commands:"
    echo "  start <task_id> [description]  Start timer for a task"
    echo "  stop [task_id]                 Stop the active timer"
    echo "  status                         Show currently active timer"
    echo "  report [start end]             Show time usage (YYYY-MM-DD range)"
    echo "  report --days <n>              Show last N days (default 7)"
    echo "  report --summary               Show total time only"
    echo "  check <task_id>                Get total time for a task"
}

case "${1:-}" in
    start)
        if [ -z "${2:-}" ]; then
            echo "Error: Task ID required" >&2
            echo "Usage: $(basename "$0") start <task_id> [description]" >&2
            exit 1
        fi
        start_timer "$2" "${3:-}"
        ;;
    stop)
        stop_timer "${2:-}"
        ;;
    status)
        active=$(get_active_timer)
        if [ -n "$active" ]; then
            echo "Active task: $active"
            current_time=$(get_task_time "$active")
            echo "Current session duration: $(format_duration "$current_time")" # Approximation
        else
            echo "No active timer."
        fi
        ;;
    check)
        if [ -z "${2:-}" ]; then
            echo "Error: Task ID required" >&2
            exit 1
        fi
        time=$(get_task_time "$2")
        echo "Total time for task $2: $(format_duration "$time")"
        ;;
    report)
        shift || true
        generate_time_report "$@"
        ;;
    *)
        show_help
        exit 1
        ;;
esac
