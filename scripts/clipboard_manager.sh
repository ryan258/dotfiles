#!/bin/bash
# clipboard_manager.sh - Enhanced clipboard management for macOS
set -euo pipefail

CLIP_DIR="$HOME/.config/dotfiles-data/clipboard_history"
mkdir -p "$CLIP_DIR"
chmod 700 "$CLIP_DIR"

MODE="${1:-}"

if [ -z "$MODE" ]; then
    echo "Usage:"
    echo "  clip save [name]  : Save current clipboard"
    echo "  clip load <name>  : Load clip to clipboard"
    echo "  clip list         : Show all saved clips"
    echo "  clip peek         : Show current clipboard content"
    exit 1
fi

case "$MODE" in
    save)
        NAME="$2"
        if [ -z "$NAME" ]; then
            NAME="clip_$(date +%H%M%S)"
        fi
        pbpaste > "$CLIP_DIR/$NAME"
        echo "Saved clipboard as '$NAME'"
        ;;
    
    load)
        if [ -z "$2" ]; then
            echo "Available clips:"
            ls "$CLIP_DIR/" 2>/dev/null || echo "No clips saved yet"
            exit 1
        fi
        clip_path="$CLIP_DIR/$2"
        if [ -f "$clip_path" ]; then
            cat "$clip_path" | pbcopy
            echo "Loaded '$2' to clipboard"
        else
            echo "Clip '$2' not found"
        fi
        ;;
    
    list)
        echo "=== Saved Clips ==="
        for clip in "$CLIP_DIR"/*; do
            if [ -f "$clip" ]; then
                echo "$(basename "$clip"): $(head -c 50 "$clip" | tr '\n' ' ')..."
            fi
        done
        ;;
    
    peek)
        echo "=== Current Clipboard ==="
        pbpaste | head -c 200
        echo ""
        ;;
    
    *)
        echo "Usage:"
        echo "  clip save [n]  : Save current clipboard"
        echo "  clip load <n>  : Load clip to clipboard"
        echo "  clip list         : Show all saved clips"
        echo "  clip peek         : Show current clipboard content"
        ;;
esac

# ---
