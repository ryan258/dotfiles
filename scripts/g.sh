#!/bin/bash
# g.sh - Consolidated navigation and state management script

# --- Configuration ---
BOOKMARKS_FILE="$HOME/.config/dotfiles-data/dir_bookmarks"
HISTORY_FILE="$HOME/.config/dotfiles-data/dir_history"
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
