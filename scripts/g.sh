#!/usr/bin/env bash
# g.sh - Consolidated navigation and state management script
# IMPORTANT: This script is SOURCED, not executed. Must use 'return' not 'exit'
# to avoid killing the parent shell

_g_is_sourced() {
  [[ "${BASH_SOURCE[0]}" != "${0}" ]]
}

g_exit() {
  local code="${1:-0}"
  if _g_is_sourced; then
    return "$code"
  fi
  exit "$code"
}

# Double-source guard (required for sourced files)
if _g_is_sourced; then
  if [[ -n "${_G_SH_LOADED:-}" ]]; then
    return 0
  fi
  readonly _G_SH_LOADED=true
fi

# Source common utilities for validation/sanitization
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# --- Configuration ---
DATA_DIR="${DATA_DIR:-$HOME/.config/dotfiles-data}"
BOOKMARKS_FILE="${BOOKMARKS_FILE:-${DIR_BOOKMARKS_FILE:-$DATA_DIR/dir_bookmarks}}"
HISTORY_FILE="${HISTORY_FILE:-${DIR_HISTORY_FILE:-$DATA_DIR/dir_history}}"
USAGE_LOG="${USAGE_LOG:-${DIR_USAGE_LOG:-$DATA_DIR/dir_usage.log}}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
APP_LAUNCHER="${APP_LAUNCHER:-$DOTFILES_DIR/scripts/app_launcher.sh}"

# --- Subcommands ---
case "${1:-list}" in
  -r|recent)
    # Show recent directories
    if [ -f "$HISTORY_FILE" ]; then
      awk -F'|' 'NF>1 {print $2; next} {print}' "$HISTORY_FILE"
    else
      echo "No directory history."
    fi
    ;;

  -s|save)
    # Save a bookmark
    shift
    if [ -z "${1:-}" ]; then
      echo "Usage: g save <bookmark_name> [-a app1,app2] [on-enter-command]"
      g_exit 1
    fi
    BOOKMARK_NAME="$1"
    if [[ "$BOOKMARK_NAME" == *"|"* ]]; then
      echo "Error: Bookmark name cannot contain '|'" >&2
      g_exit 1
    fi
    # Validate bookmark name
    if ! [[ "$BOOKMARK_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      echo "Error: Invalid bookmark name '$BOOKMARK_NAME'." >&2
      echo "Bookmark names can only contain alphanumeric characters, hyphens, and underscores." >&2
      g_exit 1
    fi
    shift
    APPS=""
    if [ "${1:-}" = "-a" ]; then
      APPS="${2:-}"
      shift 2
    fi
    if [[ "$APPS" == *"|"* ]]; then
      echo "Error: App list cannot contain '|'" >&2
      g_exit 1
    fi
    ON_ENTER_CMD="$*"
    if [[ "$ON_ENTER_CMD" == *"|"* ]]; then
      echo "Error: On-enter command cannot contain '|'" >&2
      g_exit 1
    fi
    DIR_TO_SAVE="$(pwd)"
    DIR_TO_SAVE=$(validate_path "$DIR_TO_SAVE") || g_exit 1

    # Detect venv
    VENV_PATH=""
    if [ -d "venv" ]; then
      VENV_PATH="$DIR_TO_SAVE/venv/bin/activate"
    elif [ -d ".venv" ]; then
        VENV_PATH="$DIR_TO_SAVE/.venv/bin/activate"
    fi

    BOOKMARK_NAME=$(sanitize_input "$BOOKMARK_NAME")
    DIR_TO_SAVE=$(sanitize_input "$DIR_TO_SAVE")
    ON_ENTER_CMD=$(sanitize_input "$ON_ENTER_CMD")
    VENV_PATH=$(sanitize_input "$VENV_PATH")
    APPS=$(sanitize_input "$APPS")

    echo "$BOOKMARK_NAME|$DIR_TO_SAVE|$ON_ENTER_CMD|$VENV_PATH|$APPS" >> "$BOOKMARKS_FILE"
    echo "Saved bookmark '$BOOKMARK_NAME' to $DIR_TO_SAVE"
    ;;

  list)
    # List all bookmarks
    echo "--- Bookmarks ---"
    if [ -f "$BOOKMARKS_FILE" ]; then
      if grep -q '|' "$BOOKMARKS_FILE"; then
        awk -F'|' '{printf "%-20s %-40s %-30s %-s\n", $1, $2, $3, $5}' "$BOOKMARKS_FILE"
      else
        awk -F':' '{printf "%-20s %-40s %-30s %-s\n", $1, $2, $3, $5}' "$BOOKMARKS_FILE"
      fi
    else
      echo "No bookmarks saved."
    fi
    ;;

  suggest|-i)
    # Suggest directories based on frequency and recency
    if [ ! -f "$USAGE_LOG" ]; then
        echo "No usage data to suggest from."
        g_exit 1
    fi

    NOW=$(date +%s)
    awk -F'|' -v now="$NOW" '
    {
        # Track visit count and last visit time for each directory
        dir = $2
        timestamp = $1

        if (dir in visit_count) {
            visit_count[dir]++
        } else {
            visit_count[dir] = 1
        }
        last_visit[dir] = timestamp
    }
    END {
        for (dir in visit_count) {
            # score = (visit_count) / (days_since_last_visit + 1)
            days_since = (now - last_visit[dir]) / 86400
            score = visit_count[dir] / (days_since + 1)
            printf "%.2f %s\n", score, dir
        }
    }' "$USAGE_LOG" | sort -rn | head -n "${MAX_SUGGESTIONS:-10}"
    ;;

  prune)
    # Remove dead bookmarks (directories that no longer exist)
    if [ ! -f "$BOOKMARKS_FILE" ]; then
      echo "No bookmarks file found."
      g_exit 0
    fi

    AUTO_MODE=false
    if [ "${2:-}" = "--auto" ]; then
      AUTO_MODE=true
    fi

    echo "Checking for dead bookmarks..."

    TEMP_FILE="${BOOKMARKS_FILE}.tmp"
    true > "$TEMP_FILE"

    REMOVED_COUNT=0
    KEPT_COUNT=0

    while IFS='|' read -r name dir rest; do
      if [ -d "$dir" ]; then
        # Directory exists, keep the bookmark
        echo "$name|$dir|$rest" >> "$TEMP_FILE"
        KEPT_COUNT=$((KEPT_COUNT + 1))
      else
        # Directory doesn't exist
        REMOVED_COUNT=$((REMOVED_COUNT + 1))

        if [ "$AUTO_MODE" = true ]; then
          echo "  ✗ Removed: $name -> $dir (directory not found)"
        else
          echo ""
          echo "  Dead bookmark found: $name -> $dir"
          read -p "  Remove this bookmark? (y/n) " -n 1 -r
          echo ""
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "  ✗ Removed: $name"
          else
            echo "  Kept: $name"
            echo "$name|$dir|$rest" >> "$TEMP_FILE"
            KEPT_COUNT=$((KEPT_COUNT + 1))
            REMOVED_COUNT=$((REMOVED_COUNT - 1))
          fi
        fi
      fi
    done < "$BOOKMARKS_FILE"

    # Replace bookmarks file with cleaned version
    mv "$TEMP_FILE" "$BOOKMARKS_FILE"

    echo ""
    echo "Pruning complete: $REMOVED_COUNT removed, $KEPT_COUNT kept"
    ;;

  *)
    # Default action: go to bookmark
    BOOKMARK_NAME="$1"
    if [ ! -f "$BOOKMARKS_FILE" ]; then
      echo "Error: No bookmarks saved." >&2
      g_exit 1
    fi
    BOOKMARK_DATA=$(grep "^$BOOKMARK_NAME|" "$BOOKMARKS_FILE" | head -n 1 || true)
    PARSE_MODE="pipe"
    if [ -z "$BOOKMARK_DATA" ]; then
      BOOKMARK_DATA=$(grep "^$BOOKMARK_NAME:" "$BOOKMARKS_FILE" | head -n 1 || true)
      PARSE_MODE="colon"
    fi
    if [ -z "$BOOKMARK_DATA" ]; then
      echo "Error: Bookmark '$BOOKMARK_NAME' not found."
      g_exit 1
    fi
    if [ "$PARSE_MODE" = "pipe" ]; then
      DIR=$(echo "$BOOKMARK_DATA" | cut -d'|' -f2)
      ON_ENTER_CMD=$(echo "$BOOKMARK_DATA" | cut -d'|' -f3)
      VENV_PATH=$(echo "$BOOKMARK_DATA" | cut -d'|' -f4)
      APPS=$(echo "$BOOKMARK_DATA" | cut -d'|' -f5)
    else
      DIR=$(echo "$BOOKMARK_DATA" | awk -F':' '{print $2}')
      ON_ENTER_CMD=$(echo "$BOOKMARK_DATA" | awk -F':' '{print $3}')
      VENV_PATH=$(echo "$BOOKMARK_DATA" | awk -F':' '{print $4}')
      APPS=$(echo "$BOOKMARK_DATA" | awk -F':' '{print $5}')
    fi

    # Change directory
    DIR=$(validate_path "$DIR") || g_exit 1
    cd "$DIR"

    # Activate venv if it exists
    if [ -n "$VENV_PATH" ] && [ -f "$VENV_PATH" ]; then
      echo "Activating virtual environment..."
      source "$VENV_PATH"
    fi

    # Launch apps if they exist
    if [ -n "$APPS" ] && [ -f "$APP_LAUNCHER" ]; then
        echo "Launching apps: $APPS"
        $APP_LAUNCHER $APPS || echo "  (Note: Configure favorite apps with 'app add <name> <full-app-name>')"
    fi

    # Execute on-enter command if it exists
    if [ -n "$ON_ENTER_CMD" ]; then
      echo "Executing on-enter command: '$ON_ENTER_CMD'"
      case "$ON_ENTER_CMD" in
        "ls"|"ls -la"|"git status"|"npm install"|"pwd"|"git fetch")
          $ON_ENTER_CMD
          ;;
        "")
          # No command
          ;;
        *)
          echo "Warning: Command '$ON_ENTER_CMD' is not in the allowlist. Skipping for security reasons." >&2
          ;;
      esac
    fi
    ;;
esac
