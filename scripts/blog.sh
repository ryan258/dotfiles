#!/bin/bash
# blog.sh - Tools for managing the blog content workflow.

BLOG_DIR=~/Projects/my-ms-ai-blog
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
    STUB_COUNT=$(echo "$STUB_FILES" | wc -l | tr -d ' ')
    
    echo "  • Total posts: $TOTAL_POSTS"
    echo "  • Posts needing content: $STUB_COUNT"
    
    if [ -d "$BLOG_DIR/.git" ]; then
        LAST_UPDATE=$(cd "$BLOG_DIR" && git log -1 --format="%ad" --date=short)
        echo "  • Last update: $LAST_UPDATE"
    fi
    
    echo "  • Site: https://ryanleej.com"
}

# --- Subcommand: stubs ---
function stubs() {
    echo "📄 CONTENT STUBS:"
    
    STUB_FILES=$(grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null)
    
    if [ -n "$STUB_FILES" ]; then
        echo "$STUB_FILES" | while read -r file; do
            echo "  • $(basename "$file")"
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
    *)
        echo "Usage: blog {status|stubs|random|recent}"
        ;;
esac
