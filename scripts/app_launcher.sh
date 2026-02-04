#!/usr/bin/env bash
# app_launcher.sh - macOS application launcher with favorites
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_lib "config.sh"

APPS_FILE="$DATA_DIR/favorite_apps"

case "$1" in
    add)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 add <shortname> <app_name>"
            echo "Example: $0 add code 'Visual Studio Code'"
            exit 1
        fi
        if [[ "$2" == *"|"* ]] || [[ "$3" == *"|"* ]]; then
            echo "Error: App shortname and app name cannot contain '|'" >&2
            exit 1
        fi
        shortname=$(sanitize_input "$2")
        appname=$(sanitize_input "$3")
        echo "$shortname|$appname" >> "$APPS_FILE"
        echo "Added '$shortname' -> '$appname'"
        ;;
    
    list)
        echo "=== Favorite Applications ==="
        if [ -f "$APPS_FILE" ]; then
            awk -F'|' 'NF>=2 {printf "%s -> %s\n", $1, $2}' "$APPS_FILE"
        else
            echo "No favorite apps configured."
            echo "Add some with: app add <shortname> <app_name>"
        fi
        ;;
    
    *)
        if [ -z "$1" ]; then
            echo "Usage:"
            echo "  app add <n> <app_name>  : Add favorite app"
            echo "  app list                  : List favorites"
            echo "  app <n>                : Launch favorite app"
            exit 1
        fi

        if [ ! -f "$APPS_FILE" ]; then
            echo "No favorite apps configured yet."
            exit 1
        fi

        APP_NAME=""
        while IFS='|' read -r short app_name; do
            [ -z "$short" ] && continue
            if [ "$short" = "$1" ]; then
                APP_NAME="$app_name"
                break
            fi
        done < "$APPS_FILE"

        if [ -n "$APP_NAME" ]; then
            open -a "$APP_NAME"
            echo "Launched: $APP_NAME"
        else
            echo "App '$1' not found. Use 'app list' to see available apps."
        fi
        ;;
esac

# ---
