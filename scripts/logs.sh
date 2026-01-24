#!/usr/bin/env bash
# logs.sh - View and search dotfiles system logs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

SYSTEM_LOG_FILE="${SYSTEM_LOG_FILE:-$HOME/.config/dotfiles-data/system.log}"
DISPATCHER_LOG="${DISPATCHER_USAGE_LOG:-$HOME/.config/dotfiles-data/dispatcher_usage.log}"

show_help() {
    cat << 'EOF'
Usage: logs.sh <command> [args]

Commands:
  tail              Follow the system log in real-time (default)
  today             Show today's log entries
  errors            Show only error entries
  warnings          Show warnings and errors
  search <term>     Search for a term in logs
  stats             Show log statistics
  rotate            Force log rotation
  dispatcher        Show AI dispatcher usage log
  clean             Remove logs older than 30 days

Examples:
  logs.sh                    # Follow log in real-time
  logs.sh today              # Show today's entries
  logs.sh search "todo"      # Search for "todo"
  logs.sh errors             # Show only errors
EOF
}

cmd_tail() {
    if [[ -f "$SYSTEM_LOG_FILE" ]]; then
        echo "Following $SYSTEM_LOG_FILE (Ctrl+C to exit)..."
        tail -f "$SYSTEM_LOG_FILE"
    else
        echo "No log file found at $SYSTEM_LOG_FILE"
        exit 1
    fi
}

cmd_today() {
    local today
    today=$(date '+%Y-%m-%d')

    if [[ -f "$SYSTEM_LOG_FILE" ]]; then
        grep "^$today" "$SYSTEM_LOG_FILE" || echo "No entries for today."
    else
        echo "No log file found."
    fi
}

cmd_errors() {
    if [[ -f "$SYSTEM_LOG_FILE" ]]; then
        grep "\[ERROR\]" "$SYSTEM_LOG_FILE" | tail -50 || echo "No errors found."
    else
        echo "No log file found."
    fi
}

cmd_warnings() {
    if [[ -f "$SYSTEM_LOG_FILE" ]]; then
        grep -E "\[(ERROR|WARN)\]" "$SYSTEM_LOG_FILE" | tail -50 || echo "No warnings or errors found."
    else
        echo "No log file found."
    fi
}

cmd_search() {
    local term="$1"
    if [[ -z "$term" ]]; then
        echo "Usage: logs.sh search <term>" >&2
        exit 1
    fi

    if [[ -f "$SYSTEM_LOG_FILE" ]]; then
        grep -i -- "$term" "$SYSTEM_LOG_FILE" | tail -100 || echo "No matches found for '$term'."
    else
        echo "No log file found."
    fi
}

cmd_stats() {
    echo "=== Log Statistics ==="
    echo ""

    if [[ -f "$SYSTEM_LOG_FILE" ]]; then
        local size
        if stat -f%z "$SYSTEM_LOG_FILE" >/dev/null 2>&1; then
            size=$(stat -f%z "$SYSTEM_LOG_FILE")
        else
            size=$(stat -c%s "$SYSTEM_LOG_FILE" 2>/dev/null || echo 0)
        fi
        local size_human=$((size / 1024))

        echo "System Log: $SYSTEM_LOG_FILE"
        echo "  Size: ${size_human}KB"
        echo "  Total entries: $(wc -l < "$SYSTEM_LOG_FILE" | tr -d ' ')"
        echo "  Errors: $(grep -c "\[ERROR\]" "$SYSTEM_LOG_FILE" 2>/dev/null || echo 0)"
        echo "  Warnings: $(grep -c "\[WARN\]" "$SYSTEM_LOG_FILE" 2>/dev/null || echo 0)"
        echo "  Info: $(grep -c "\[INFO\]" "$SYSTEM_LOG_FILE" 2>/dev/null || echo 0)"

        echo ""
        echo "Recent activity by script:"
        awk -F'[][]' '{print $4}' "$SYSTEM_LOG_FILE" 2>/dev/null | cut -d':' -f1 | sort | uniq -c | sort -rn | head -10
    else
        echo "No system log found."
    fi

    echo ""
    if [[ -f "$DISPATCHER_LOG" ]]; then
        echo "Dispatcher Log: $DISPATCHER_LOG"
        echo "  Total API calls: $(wc -l < "$DISPATCHER_LOG" | tr -d ' ')"
        echo ""
        echo "Usage by dispatcher:"
        awk -F'DISPATCHER: ' '{print $2}' "$DISPATCHER_LOG" 2>/dev/null | cut -d',' -f1 | sort | uniq -c | sort -rn | head -10
    else
        echo "No dispatcher log found."
    fi
}

cmd_rotate() {
    echo "Rotating logs..."
    rotate_log "$SYSTEM_LOG_FILE"
    if [[ -f "$DISPATCHER_LOG" ]]; then
        rotate_log "$DISPATCHER_LOG"
    fi
    echo "Log rotation complete."
}

cmd_dispatcher() {
    if [[ -f "$DISPATCHER_LOG" ]]; then
        echo "=== AI Dispatcher Usage (last 20 entries) ==="
        tail -20 "$DISPATCHER_LOG"
    else
        echo "No dispatcher log found."
    fi
}

cmd_clean() {
    echo "Cleaning old log files..."
    local count=0

    # Find and remove rotated logs older than 30 days
    for log in "$SYSTEM_LOG_FILE".* "$DISPATCHER_LOG".* ; do
        if [[ -f "$log" ]]; then
            # Check if older than 30 days
            local age_days
            if stat -f %m "$log" >/dev/null 2>&1; then
                local mtime
                mtime=$(stat -f %m "$log")
                local now
                now=$(date +%s)
                age_days=$(( (now - mtime) / 86400 ))
            else
                age_days=$(( ($(date +%s) - $(stat -c %Y "$log" 2>/dev/null || echo 0)) / 86400 ))
            fi

            if (( age_days > 30 )); then
                rm -f "$log"
                ((count++))
            fi
        fi
    done

    echo "Removed $count old log files."
}

# Main dispatcher
case "${1:-tail}" in
    tail)       cmd_tail ;;
    today)      cmd_today ;;
    errors)     cmd_errors ;;
    warnings)   cmd_warnings ;;
    search)     shift; cmd_search "$@" ;;
    stats)      cmd_stats ;;
    rotate)     cmd_rotate ;;
    dispatcher) cmd_dispatcher ;;
    clean)      cmd_clean ;;
    -h|--help|help) show_help ;;
    *)
        echo "Unknown command: $1" >&2
        show_help
        exit 1
        ;;
esac
