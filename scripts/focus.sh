#!/usr/bin/env bash
set -euo pipefail

# --- focus.sh: Set or display the focus for the day ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/lib/common.sh"
else
  echo "Error: common library not found at $SCRIPT_DIR/lib/common.sh" >&2
  exit 1
fi
if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/lib/config.sh"
else
  die "configuration library not found at $SCRIPT_DIR/lib/config.sh" "$EXIT_FILE_NOT_FOUND"
fi
if [ -f "$SCRIPT_DIR/lib/date_utils.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/lib/date_utils.sh"
else
  die "date utilities not found at $SCRIPT_DIR/lib/date_utils.sh" "$EXIT_FILE_NOT_FOUND"
fi

FOCUS_FILE="${FOCUS_FILE:?FOCUS_FILE is not set by config.sh}"
HISTORY_FILE="${FOCUS_HISTORY_FILE:?FOCUS_HISTORY_FILE is not set by config.sh}"

sanitize_focus_text() {
  local value
  value=$(sanitize_input "$1")
  value=${value//$'\n'/ }
  printf '%s' "$value"
}

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
      echo "Usage: focus set \"Your task here\""
      log_error "focus set requires a non-empty focus task"
      exit "$EXIT_INVALID_ARGS"
    fi
    
    # 1. Archive existing focus if present (so we don't lose it)
    if [ -f "$FOCUS_FILE" ] && [ -s "$FOCUS_FILE" ]; then
        old_focus=$(cat "$FOCUS_FILE")
        today=$(date_today)
        mkdir -p "$(dirname "$HISTORY_FILE")"
        touch "$HISTORY_FILE"

        # Sanitize and log as 'replaced'
        focus_clean=$(sanitize_focus_text "$old_focus")
        echo "$today|$focus_clean (Replaced)" >> "$HISTORY_FILE"
    fi

    # 2. Set new focus
    mkdir -p "$(dirname "$FOCUS_FILE")"
    focus_text=$(sanitize_focus_text "$*")
    echo "$focus_text" > "$FOCUS_FILE"
    echo "🎯 Focus set: $focus_text"
    ;;
  done)
    if [ -f "$FOCUS_FILE" ] && [ -s "$FOCUS_FILE" ]; then
      focus_text=$(cat "$FOCUS_FILE")
      today=$(date_today)
      # Ensure history directory and file exist
      mkdir -p "$(dirname "$HISTORY_FILE")"
      touch "$HISTORY_FILE"
      
      focus_clean=$(sanitize_focus_text "$focus_text")
      
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
    show_usage
    log_error "focus.sh unknown command: ${1:-<empty>}"
    exit "$EXIT_INVALID_ARGS"
    ;;
esac
