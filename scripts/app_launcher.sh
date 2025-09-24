#!/bin/bash
# app_launcher.sh - macOS application launcher with favorites

APPS_FILE=~/.favorite_apps

case "$1" in
    add)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 add <shortname> <app_name>"
            echo "Example: $0 add code 'Visual Studio Code'"
            exit 1
        fi
        echo "$2:$3" >> "$APPS_FILE"
        echo "Added '$2' -> '$3'"
        ;;
    
    list)
        echo "=== Favorite Applications ==="
        if [ -f "$APPS_FILE" ]; then
            cat "$APPS_FILE" | sed 's/:/ -> /'
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
        
        if [ -f "$APPS_FILE" ]; then
            APP_NAME=$(grep "^$1:" "$APPS_FILE" | cut -d: -f2-)
            if [ -n "$APP_NAME" ]; then
                open -a "$APP_NAME"
                echo "Launched: $APP_NAME"
            else
                echo "App '$1' not found. Use 'app list' to see available apps."
            fi
        else
            echo "No favorite apps configured yet."
        fi
        ;;
esac

# ---