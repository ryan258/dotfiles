#!/bin/bash
# g.sh - Consolidated navigation and state management script

# --- Configuration ---
BOOKMARKS_FILE="$HOME/.config/dotfiles-data/dir_bookmarks"
HISTORY_FILE="$HOME/.config/dotfiles-data/dir_history"
USAGE_LOG="$HOME/.config/dotfiles-data/dir_usage.log"
APP_LAUNCHER="$HOME/dotfiles/scripts/app_launcher.sh"

# --- Subcommands ---
case "${1:-list}" in
  -r|recent)
    # Show recent directories
    if [ -f "$HISTORY_FILE" ]; then
      cat "$HISTORY_FILE"
    else
      echo "No directory history."
    fi
    ;;

  -s|save)
    # Save a bookmark
    shift
    if [ -z "$1" ]; then
      echo "Usage: g save <bookmark_name> [-a app1,app2] [on-enter-command]"
      exit 1
    fi
    BOOKMARK_NAME="$1"
    shift
    APPS=""
    if [ "$1" == "-a" ]; then
      APPS="$2"
      shift 2
    fi
    ON_ENTER_CMD="$*"
    DIR_TO_SAVE="$(pwd)"

    # Detect venv
    VENV_PATH=""
    if [ -d "venv" ]; then
      VENV_PATH="$DIR_TO_SAVE/venv/bin/activate"
    elif [ -d ".venv" ]; then
        VENV_PATH="$DIR_TO_SAVE/.venv/bin/activate"
    fi

    echo "$BOOKMARK_NAME:$DIR_TO_SAVE:$ON_ENTER_CMD:$VENV_PATH:$APPS" >> "$BOOKMARKS_FILE"
    echo "Saved bookmark '$BOOKMARK_NAME' to $DIR_TO_SAVE"
    ;;

  list)
    # List all bookmarks
    echo "--- Bookmarks ---"
    if [ -f "$BOOKMARKS_FILE" ]; then
      awk -F':' '{printf "%-20s %-40s %-30s %-s\n", $1, $2, $3, $5}' "$BOOKMARKS_FILE"
    else
      echo "No bookmarks saved."
    fi
    ;;

  suggest|-i)
    # Suggest directories based on frequency and recency
    if [ ! -f "$USAGE_LOG" ]; then
        echo "No usage data to suggest from."
        exit 1
    fi

    NOW=$(date +%s)
    awk -F':' -v now="$NOW" '
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
    }' "$USAGE_LOG" | sort -rn | head -n 10
    ;;

  prune)
    # Remove dead bookmarks (directories that no longer exist)
    if [ ! -f "$BOOKMARKS_FILE" ]; then
      echo "No bookmarks file found."
      exit 0
    fi

    AUTO_MODE=false
    if [ "${2:-}" == "--auto" ]; then
      AUTO_MODE=true
    fi

    echo "Checking for dead bookmarks..."

    TEMP_FILE="${BOOKMARKS_FILE}.tmp"
    > "$TEMP_FILE"

    REMOVED_COUNT=0
    KEPT_COUNT=0

    while IFS=':' read -r name dir rest; do
      if [ -d "$dir" ]; then
        # Directory exists, keep the bookmark
        echo "$name:$dir:$rest" >> "$TEMP_FILE"
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
            echo "$name:$dir:$rest" >> "$TEMP_FILE"
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
    BOOKMARK_DATA=$(grep "^$BOOKMARK_NAME:" "$BOOKMARKS_FILE" | head -n 1)
    if [ -z "$BOOKMARK_DATA" ]; then
      echo "Error: Bookmark '$BOOKMARK_NAME' not found."
      exit 1
    fi
    DIR=$(echo "$BOOKMARK_DATA" | cut -d':' -f2)
    ON_ENTER_CMD=$(echo "$BOOKMARK_DATA" | cut -d':' -f3)
    VENV_PATH=$(echo "$BOOKMARK_DATA" | cut -d':' -f4)
    APPS=$(echo "$BOOKMARK_DATA" | cut -d':' -f5)

    # Log directory visit for smart suggestions
    echo "$(date +%s):$DIR" >> "$USAGE_LOG"

    # Change directory
    cd "$DIR"

    # Activate venv if it exists
    if [ -n "$VENV_PATH" ] && [ -f "$VENV_PATH" ]; then
      echo "Activating virtual environment..."
      source "$VENV_PATH"
    fi

    # Launch apps if they exist
    if [ -n "$APPS" ] && [ -f "$APP_LAUNCHER" ]; then
        echo "Launching apps: $APPS"
        "$APP_LAUNCHER" $APPS
    fi

    # Execute on-enter command if it exists
    if [ -n "$ON_ENTER_CMD" ]; then
      eval "$ON_ENTER_CMD"
    fi
    ;;
esac
