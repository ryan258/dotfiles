#!/bin/bash
# blog.sh - Tools for managing the blog content workflow.

# Use the BLOG_DIR environment variable if it is set, otherwise use the default.
SYSTEM_LOG_FILE="$HOME/.config/dotfiles-data/system.log"
BLOG_DIR="${BLOG_DIR:-$HOME/Projects/my-ms-ai-blog}"
POSTS_DIR="$BLOG_DIR/content/posts"

if [ ! -d "$POSTS_DIR" ]; then
    echo "Blog directory not found at $POSTS_DIR"
    exit 1
fi

# --- Subcommand: status ---
function status() {
    echo "📝 BLOG STATUS (ryanleej.com):"

    TOTAL_POSTS=$(find "$POSTS_DIR" -name "*.md" | wc -l | tr -d ' ')
    STUB_FILES=$(grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null)
    STUB_COUNT=$(echo "$STUB_FILES" | grep -c . || echo "0")

    echo "  • Total posts: $TOTAL_POSTS"
    echo "  • Posts needing content: $STUB_COUNT"

    # Check for stale stubs (>7 days old)
    if [ -n "$STUB_FILES" ]; then
        SEVEN_DAYS_AGO=$(date -v-7d +%s)
        stale_count=0

        echo "$STUB_FILES" | while read -r file; do
            if [ -f "$file" ]; then
                if [ -d "$BLOG_DIR/.git" ]; then
                    last_commit=$(cd "$BLOG_DIR" && git log -1 --format="%ct" -- "$file" 2>/dev/null)
                    if [ -n "$last_commit" ] && [ "$last_commit" -lt "$SEVEN_DAYS_AGO" ]; then
                        stale_count=$((stale_count + 1))
                    fi
                fi
            fi
        done

        # Count stale stubs for display
        STALE_STUBS=0
        for file in $STUB_FILES; do
            if [ -f "$file" ] && [ -d "$BLOG_DIR/.git" ]; then
                last_commit=$(cd "$BLOG_DIR" && git log -1 --format="%ct" -- "$file" 2>/dev/null)
                if [ -n "$last_commit" ] && [ "$last_commit" -lt "$SEVEN_DAYS_AGO" ]; then
                    STALE_STUBS=$((STALE_STUBS + 1))
                fi
            fi
        done

        if [ "$STALE_STUBS" -gt 0 ]; then
            echo "  ⚠️  Stale stubs (>7 days): $STALE_STUBS"
        fi
    fi

    if [ -d "$BLOG_DIR/.git" ]; then
        LAST_UPDATE=$(cd "$BLOG_DIR" && git log -1 --format="%ad" --date=short)
        echo "  • Last update: $LAST_UPDATE"

        # Calculate days since last update
        LAST_UPDATE_EPOCH=$(cd "$BLOG_DIR" && git log -1 --format="%ct")
        DAYS_SINCE=$(( ( $(date +%s) - LAST_UPDATE_EPOCH ) / 86400 ))

        if [ "$DAYS_SINCE" -gt 14 ]; then
            echo "  ⏰ It's been $DAYS_SINCE days since your last update"
        fi
    fi

    echo "  • Site: https://ryanleej.com"
}

# --- Subcommand: stubs ---
function stubs() {
    echo "📄 CONTENT STUBS:"

    STUB_FILES=$(grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null)

    if [ -n "$STUB_FILES" ]; then
        SEVEN_DAYS_AGO=$(date -v-7d +%s)
        THIRTY_DAYS_AGO=$(date -v-30d +%s)

        echo "$STUB_FILES" | while read -r file; do
            filename=$(basename "$file")

            # Get last modified timestamp
            if [ -d "$BLOG_DIR/.git" ]; then
                # Try to get last git commit date for this file
                last_commit=$(cd "$BLOG_DIR" && git log -1 --format="%ct" -- "$file" 2>/dev/null)
                if [ -n "$last_commit" ]; then
                    mod_time=$last_commit
                else
                    # Fall back to file system modification time
                    mod_time=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null)
                fi
            else
                mod_time=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null)
            fi

            # Calculate age and add warning if old
            if [ "$mod_time" -lt "$THIRTY_DAYS_AGO" ]; then
                days_old=$(( ( $(date +%s) - mod_time ) / 86400 ))
                echo "  ⚠️  $filename (stale: ${days_old} days old)"
            elif [ "$mod_time" -lt "$SEVEN_DAYS_AGO" ]; then
                days_old=$(( ( $(date +%s) - mod_time ) / 86400 ))
                echo "  ⏰ $filename (${days_old} days old)"
            else
                echo "  • $filename"
            fi
        done
    else
        echo "  (No content stubs found)"
    fi
}

# --- Subcommand: random ---
function random_stub() {
    echo "🎲 Opening a random stub..."
    
    STUB_FILES=($(grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null))
    
    if [ ${#STUB_FILES[@]} -eq 0 ]; then
        echo "  (No content stubs to choose from)"
        return
    fi
    
    RANDOM_INDEX=$(( RANDOM % ${#STUB_FILES[@]} ))
    RANDOM_FILE=${STUB_FILES[$RANDOM_INDEX]}
    
    echo "  Opening: $(basename "$RANDOM_FILE")"
    
    if command -v code &> /dev/null; then
        code "$RANDOM_FILE"
    else
        open "$RANDOM_FILE"
    fi
}

# --- Subcommand: recent ---
function recent() {
    echo "⏳ RECENTLY MODIFIED POSTS:"
    
    find "$POSTS_DIR" -name "*.md" -mtime -14 -print0 | xargs -0 ls -t | head -n 5 | while read -r file; do
        if [ -f "$file" ]; then
            echo "  • $(basename "$file")"
        fi
    done
}

function sync_tasks() {
    echo "🔄 Syncing blog stubs with todo list..."
    STUB_FILES=$(grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null)
    TODO_FILE="$HOME/.config/dotfiles-data/todo.txt"

    if [ -n "$STUB_FILES" ]; then
        echo "$STUB_FILES" | while read -r file; do
            filename=$(basename "$file" .md)
            task_text="BLOG: $filename"
            if ! grep -q "$task_text" "$TODO_FILE"; then
                echo "  Adding task: $task_text"
                echo "$(date): blog.sh - Adding task '$task_text' to todo list." >> "$SYSTEM_LOG_FILE"
                todo.sh add "$task_text"
            fi
        done
    fi
    echo "Sync complete."
}

function ideas() {
    echo "💡 Searching for blog ideas in journal..."
    /Users/ryanjohnson/dotfiles/scripts/journal.sh search "blog idea"
}

# --- Main Logic ---
case "$1" in
    status)
        status
        ;;
    stubs)
        stubs
        ;;
    random)
        random_stub
        ;;
    recent)
        recent
        ;;
    sync)
        sync_tasks
        ;;
    ideas)
        ideas
        ;;
    *)
        echo "Usage: blog {status|stubs|random|recent|sync|ideas}"
        ;;
esac
