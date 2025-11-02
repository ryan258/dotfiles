#!/bin/bash
# workspace_manager.sh - Manage different work contexts

WORKSPACE_DIR=~/.workspaces
mkdir -p "$WORKSPACE_DIR"

is_sourced() {
    if [ -n "$ZSH_VERSION" ]; then
        case $ZSH_EVAL_CONTEXT in
            *:file) return 0 ;;
        esac
        return 1
    elif [ -n "$BASH_VERSION" ]; then
        [[ ${BASH_SOURCE[0]} != "$0" ]]
        return
    fi
    return 1
}

case "$1" in
    save)
        if [ -z "$2" ]; then
            echo "Usage: workspace save <workspace_name>"
            exit 1
        fi
        
        WORKSPACE_FILE="$WORKSPACE_DIR/$2.workspace"
        
        echo "# Workspace: $2" > "$WORKSPACE_FILE"
        echo "# Saved: $(date)" >> "$WORKSPACE_FILE"
        echo "DIRECTORY=$(pwd)" >> "$WORKSPACE_FILE"
        
        # Save currently open applications
        echo "# Open Applications:" >> "$WORKSPACE_FILE"
        osascript -e 'tell application "System Events" to get name of (processes where background only is false)' >> "$WORKSPACE_FILE"
        
        echo "Workspace '$2' saved"
        ;;
    
    load)
        if [ -z "$2" ]; then
            echo "Available workspaces:"
            found=false
            while IFS= read -r workspace; do
                found=true
                basename "$workspace" .workspace
            done < <(find "$WORKSPACE_DIR" -maxdepth 1 -type f -name '*.workspace' -print)
            if [ "$found" = false ]; then
                echo "No workspaces saved"
            fi
            exit 1
        fi
        
        WORKSPACE_FILE="$WORKSPACE_DIR/$2.workspace"
        if [ -f "$WORKSPACE_FILE" ]; then
            echo "Loading workspace: $2"
            
            # Extract and go to directory
            DIR=$(grep "^DIRECTORY=" "$WORKSPACE_FILE" | cut -d= -f2)
            if [ -n "$DIR" ] && [ -d "$DIR" ]; then
                if is_sourced; then
                    if ! builtin cd "$DIR"; then
                        echo "Failed to change directory to: $DIR"
                        return 1
                    fi
                    echo "Switched to: $DIR"
                else
                    echo "$DIR"
                    printf "Tip: source %s to switch directories automatically.\n" "$0" >&2
                fi
            fi
            
            echo "Workspace '$2' loaded"
        else
            echo "Workspace '$2' not found"
        fi
        ;;
    
    list)
        echo "=== Saved Workspaces ==="
        for workspace in "$WORKSPACE_DIR"/*.workspace; do
            if [ -f "$workspace" ]; then
                NAME=$(basename "$workspace" .workspace)
                SAVED=$(grep "# Saved:" "$workspace" | cut -d: -f2-)
                echo "$NAME -$SAVED"
            fi
        done
        ;;
    
    *)
        echo "Usage: $0 {save|load|list}"
        echo "  save <n>  : Save current workspace"
        echo "  load <n>  : Load workspace"
        echo "  list         : List all workspaces"
        ;;
esac

# ---
