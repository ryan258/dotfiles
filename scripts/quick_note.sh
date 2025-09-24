#!/bin/bash
# quick_note.sh - Fast note-taking with search functionality

NOTES_FILE=~/quick_notes.txt

case "$1" in
    add)
        shift
        note="$*"
        if [ -z "$note" ]; then
            echo "Usage: $0 add <your note>"
            exit 1
        fi
        printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M')" "$note" >> "$NOTES_FILE"
        printf "Note added: %s\n" "$note"
        ;;
    
    search)
        shift
        query="$*"
        if [ -z "$query" ]; then
            echo "Usage: $0 search <search_term>"
            exit 1
        fi
        printf "=== Notes containing '%s' ===\n" "$query"
        grep -i -F -- "$query" "$NOTES_FILE" 2>/dev/null || echo "No matching notes found."
        ;;
    
    recent)
        COUNT=${2:-10}
        echo "=== Last $COUNT Notes ==="
        tail -n "$COUNT" "$NOTES_FILE" 2>/dev/null || echo "No notes found."
        ;;
    
    today)
        TODAY=$(date '+%Y-%m-%d')
        echo "=== Notes from today ($TODAY) ==="
        grep "^\\[$TODAY" "$NOTES_FILE" 2>/dev/null || echo "No notes from today."
        ;;
    
    *)
        echo "Usage: $0 {add|search|recent|today}"
        echo "  add <note>      : Add a quick note"
        echo "  search <term>   : Search through notes"
        echo "  recent [count]  : Show recent notes (default: 10)"
        echo "  today           : Show today's notes"
        ;;
esac

# ---
