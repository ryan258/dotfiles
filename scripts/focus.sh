#!/bin/bash
set -euo pipefail

# --- focus.sh: Set or display the focus for the day ---

FOCUS_FILE="$HOME/.config/dotfiles-data/daily_focus.txt"
HISTORY_FILE="$HOME/.config/dotfiles-data/focus_history.log"

show_usage() {
  echo "Usage: focus <command> [args]"
  echo "Commands:"
  echo "  (no args)        Show current focus"
  echo "  set \"Task\"       Set today's focus"
  echo "  done             Mark focus as complete and archive to history"
  echo "  history          Show focus history"
  echo "  clear            Clear current focus (without archiving)"
}

case "${1:-show}" in
  show|check)
    if [ -f "$FOCUS_FILE" ] && [ -s "$FOCUS_FILE" ]; then
      echo "🎯 Focus for Today: $(cat "$FOCUS_FILE")"
    else
      echo "No focus set for today."
      echo "Set one with: focus set \"Your focus\""
    fi
    ;;
  set)
    shift
    if [ -z "${1:-}" ]; then
      echo "Error: Please provide a focus task."
      echo "Usage: focus set \"Your task here\""
      exit 1
    fi
    
    # 1. Archive existing focus if present (so we don't lose it)
    if [ -f "$FOCUS_FILE" ] && [ -s "$FOCUS_FILE" ]; then
        old_focus=$(cat "$FOCUS_FILE")
        today=$(date +%Y-%m-%d)
        mkdir -p "$(dirname "$HISTORY_FILE")"
        touch "$HISTORY_FILE"
        
        # Sanitize and log as 'replaced' or just log it
        # We'll treat it as a completed/past focus for the day
        focus_clean=$(echo "$old_focus" | tr '|' '-')
        echo "$today|$focus_clean (Replaced)" >> "$HISTORY_FILE"
    fi

    # 2. Set new focus
    mkdir -p "$(dirname "$FOCUS_FILE")"
    echo "$*" > "$FOCUS_FILE"
    echo "🎯 Focus set: $*"
    ;;
  done)
    if [ -f "$FOCUS_FILE" ] && [ -s "$FOCUS_FILE" ]; then
      focus_text=$(cat "$FOCUS_FILE")
      today=$(date +%Y-%m-%d)
      # Ensure history directory and file exist
      mkdir -p "$(dirname "$HISTORY_FILE")"
      touch "$HISTORY_FILE"
      
      # Sanitize pipes in focus text before logging to prevent corruption
      focus_clean=$(echo "$focus_text" | tr '|' '-')
      
      echo "$today|$focus_clean" >> "$HISTORY_FILE"
      rm -f "$FOCUS_FILE"
      echo "✅ Focus completed and archived: $focus_text"
    else
      echo "No active focus to complete."
    fi
    ;;
  history)
    if [ -f "$HISTORY_FILE" ]; then
      echo "=== Focus History ==="
      # Simple formatting: Replace pipe with " - " and show last 20
      tail -n 20 "$HISTORY_FILE" | sed 's/|/ - /'
    else
      echo "No history found."
    fi
    ;;
  clear)
    rm -f "$FOCUS_FILE"
    echo "Focus for the day has been cleared."
    ;;
  help|--help|-h)
    show_usage
    ;;
  *)
    # Fallback to 'set' implementation for backward compatibility if user types `focus "Something"`
    # But strictly speaking, the case statement handles $1. 
    # If $1 is not one of the above keywords, treat it as the focus text (implicit set)
    mkdir -p "$(dirname "$FOCUS_FILE")"
    echo "$*" > "$FOCUS_FILE"
    echo "🎯 Focus set: $*"
    ;;
esac
