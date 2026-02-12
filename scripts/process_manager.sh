#!/usr/bin/env bash
# process_manager.sh - Find and manage processes on macOS
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/common.sh"
fi

sanitize_pattern() {
    local value
    value=$(sanitize_input "$1")
    value=${value//$'\n'/ }
    if [[ -z "$value" ]]; then
        echo "Error: Process name is required." >&2
        return 1
    fi
    if [[ "$value" == -* ]]; then
        echo "Error: Process name cannot start with '-'." >&2
        return 1
    fi
    printf '%s' "$value"
}

COMMAND="${1:-}"

case "$COMMAND" in
    find)
        if [ -z "${2:-}" ]; then
            echo "Usage: $0 find <process_name>"
            exit 1
        fi
        pattern=$(sanitize_pattern "$2") || exit 1
        echo "Searching for processes containing '$pattern'..."
        pgrep -fl "$pattern"
        ;;
    
    top)
        echo "=== Top 10 CPU-using processes ==="
        ps aux | sort -nr -k 3 | head -10
        ;;
    
    memory)
        echo "=== Top 10 Memory-using processes ==="
        ps aux | sort -nr -k 4 | head -10
        ;;
    
    kill)
        if [ -z "${2:-}" ]; then
            echo "Usage: $0 kill <process_name>"
            exit 1
        fi
        
        pattern=$(sanitize_pattern "$2") || exit 1
        PIDS=$(pgrep -i "$pattern")
        if [ -z "$PIDS" ]; then
            echo "No processes found matching '$pattern'"
            exit 1
        fi
        
        echo "Found processes matching '$pattern':"
        pgrep -fl "$pattern"
        echo ""
        IFS= read -r -p "Kill these processes? (y/n): " confirm
        
        if [[ "$confirm" == [yY] ]]; then
            pkill -i "$pattern"
            echo "Processes killed."
        else
            echo "Operation cancelled."
        fi
        ;;
    
    *)
        echo "Usage: $0 {find|top|memory|kill} [process_name]"
        echo "  find <name>   : Find processes by name"
        echo "  top           : Show top CPU users"
        echo "  memory        : Show top memory users"
        echo "  kill <name>   : Safely kill processes by name"
        exit 1
        ;;
esac

# ---
