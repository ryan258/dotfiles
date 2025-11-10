#!/bin/bash
# process_manager.sh - Find and manage processes on macOS
set -euo pipefail

case "$1" in
    find)
        if [ -z "$2" ]; then
            echo "Usage: $0 find <process_name>"
            exit 1
        fi
        echo "Searching for processes containing '$2'..."
        ps aux | grep -i "$2" | grep -v grep
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
        if [ -z "$2" ]; then
            echo "Usage: $0 kill <process_name>"
            exit 1
        fi
        
        PIDS=$(pgrep -i "$2")
        if [ -z "$PIDS" ]; then
            echo "No processes found matching '$2'"
            exit 1
        fi
        
        echo "Found processes matching '$2':"
        ps aux | grep -i "$2" | grep -v grep
        echo ""
        IFS= read -r -p "Kill these processes? (y/n): " confirm
        
        if [[ "$confirm" == [yY] ]]; then
            pkill -i "$2"
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
        ;;
esac

# ---
