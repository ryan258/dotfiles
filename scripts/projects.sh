#!/bin/bash
# projects.sh - Find and recall forgotten projects.

PROJECTS_DIR=~/Projects

# --- Subcommand: forgotten ---
function forgotten() {
    echo "🗂️ PROJECTS NOT TOUCHED IN 60+ DAYS:"
    
    if [ ! -d "$PROJECTS_DIR" ]; then
        echo "  (Projects directory not found at $PROJECTS_DIR)"
        return
    fi

    NOW=$(date +%s)
    
    # Create a temporary file to store results for sorting
    TMP_FILE=$(mktemp)

    find "$PROJECTS_DIR" -maxdepth 1 -type d | while read -r project_path; do
        if [ -d "$project_path/.git" ]; then
            LAST_MOD_EPOCH=$(stat -f "%m" "$project_path")
            DAYS_AGO=$(( (NOW - LAST_MOD_EPOCH) / 86400 ))
            
            if [ "$DAYS_AGO" -ge 60 ]; then
                PROJECT_NAME=$(basename "$project_path")
                echo "$DAYS_AGO $PROJECT_NAME" >> "$TMP_FILE"
            fi
        fi
    done

    # Sort by days ago (descending) and print
    sort -rn "$TMP_FILE" | while read -r line; do
        DAYS_AGO=$(echo "$line" | awk '{print $1}')
        PROJECT_NAME=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
        echo "  • $PROJECT_NAME ($DAYS_AGO days ago)"
    done

    rm "$TMP_FILE"
    
    echo ""
    echo "Run 'projects recall <name>' to see details"
}

# --- Subcommand: recall ---
function recall() {
    if [ -z "$1" ]; then
        echo "Usage: projects recall <project_name>"
        return
    fi
    
    PROJECT_NAME="$1"
    PROJECT_PATH="$PROJECTS_DIR/$PROJECT_NAME"
    
    if [ ! -d "$PROJECT_PATH" ]; then
        echo "Project '$PROJECT_NAME' not found at $PROJECT_PATH"
        return
    fi
    
    echo "📦 Project: $PROJECT_NAME"
    
    NOW=$(date +%s)
    LAST_MOD_EPOCH=$(stat -f "%m" "$PROJECT_PATH")
    DAYS_AGO=$(( (NOW - LAST_MOD_EPOCH) / 86400 ))
    echo "Last modified: $DAYS_AGO days ago"
    
    if [ -d "$PROJECT_PATH/.git" ]; then
        LAST_COMMIT=$(cd "$PROJECT_PATH" && git log -1 --format='"%s"')
        echo "Last commit: $LAST_COMMIT"
    fi
    
    if [ -f "$PROJECT_PATH/README.md" ]; then
        echo "README preview:"
        head -n 5 "$PROJECT_PATH/README.md" | sed 's/^/  /'
    fi
    
    echo "Path: $PROJECT_PATH"
    echo ""
    echo "Commands: cd to navigate, goto to bookmark"
}

# --- Main Logic ---
case "$1" in
    forgotten)
        forgotten
        ;;
    recall)
        shift
        recall "$@"
        ;;
    *)
        echo "Usage: projects {forgotten|recall <name>}"
        ;;
esac
