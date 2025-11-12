#!/bin/bash
# blog.sh - Tools for managing the blog content workflow.
set -euo pipefail

SYSTEM_LOG_FILE="$HOME/.config/dotfiles-data/system.log"

# Source shared utilities
if [ -f "$HOME/dotfiles/bin/dhp-utils.sh" ]; then
    # shellcheck disable=SC1090
    source "$HOME/dotfiles/bin/dhp-utils.sh"
else
    echo "Error: Shared utility library dhp-utils.sh not found." >&2
    exit 1
fi

# Allow per-user overrides via .env without leaking secrets broadly.
if [ -f "$HOME/dotfiles/.env" ]; then
    # shellcheck disable=SC1090
    source "$HOME/dotfiles/.env"
fi

# Check that BLOG_DIR is configured
BLOG_DIR="${BLOG_DIR:-}"
if [ -z "$BLOG_DIR" ]; then
    echo "Blog workflows are disabled. Set BLOG_DIR in dotfiles/.env to use blog.sh."
    exit 1
fi

# Determine directory paths
DRAFTS_DIR="${BLOG_DRAFTS_DIR_OVERRIDE:-${CONTENT_OUTPUT_DIR:-$BLOG_DIR/drafts}}"
POSTS_DIR="${BLOG_POSTS_DIR_OVERRIDE:-$BLOG_DIR/content/posts}"

# Create directories if they don't exist (mkdir -p is safe to run multiple times)
mkdir -p "$BLOG_DIR"
mkdir -p "$DRAFTS_DIR"
mkdir -p "$POSTS_DIR"

# Validate paths ONLY if they're under $HOME (security check for default configs)
# Skip validation for explicit external paths (e.g., /var/www/blog)
if [[ "$BLOG_DIR" == "$HOME"* ]]; then
    VALIDATED_BLOG_DIR=$(validate_path "$BLOG_DIR") || exit 1
    BLOG_DIR="$VALIDATED_BLOG_DIR"
fi

if [[ "$DRAFTS_DIR" == "$HOME"* ]]; then
    VALIDATED_DRAFTS_DIR=$(validate_path "$DRAFTS_DIR") || exit 1
    DRAFTS_DIR="$VALIDATED_DRAFTS_DIR"
fi

if [[ "$POSTS_DIR" == "$HOME"* ]]; then
    VALIDATED_POSTS_DIR=$(validate_path "$POSTS_DIR") || exit 1
    POSTS_DIR="$VALIDATED_POSTS_DIR"
fi

# Final check that posts directory exists (should always pass after mkdir -p)
if [ ! -d "$POSTS_DIR" ]; then
    echo "Error: Failed to create or access blog directory at $POSTS_DIR"
    exit 1
fi

# --- Subcommand: status ---
function status() {
    echo "📝 BLOG STATUS (ryanleej.com):"

    TOTAL_POSTS=$(find "$POSTS_DIR" -name "*.md" | wc -l | tr -d ' ')
    STUB_FILES=$(grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null || true)
    if [ -n "$STUB_FILES" ]; then
        STUB_COUNT=$(printf "%s\n" "$STUB_FILES" | grep -c . || true)
    else
        STUB_COUNT=0
    fi

    echo "  • Total posts: $TOTAL_POSTS"
    echo "  • Posts needing content: $STUB_COUNT"

    if [ -d "$DRAFTS_DIR" ]; then
        draft_count=0
        drafts_list=""
        while IFS= read -r draft; do
            drafts_list="${drafts_list}${draft}"$'\n'
            draft_count=$((draft_count + 1))
        done < <(find "$DRAFTS_DIR" -type f -name "*.md" 2>/dev/null | sort)

        if [ "$draft_count" -gt 0 ]; then
            echo "  • Drafts awaiting review ($draft_count):"
            while IFS= read -r draft; do
                [ -z "$draft" ] && continue
                rel=${draft#"$DRAFTS_DIR"/}
                echo "    - $rel"
            done <<< "$drafts_list"
        else
            echo "  • Drafts awaiting review: 0"
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
    
    mapfile -t STUB_FILES < <(grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null)
    
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

    recent_files=()
    while IFS= read -r -d '' file; do
        recent_files+=("$file")
    done < <(find "$POSTS_DIR" -name "*.md" -mtime -14 -print0 2>/dev/null)

    if [ ${#recent_files[@]} -eq 0 ]; then
        echo "  (No posts updated in the last 14 days)"
        return
    fi

    printf '%s\0' "${recent_files[@]}" | xargs -0 ls -t | head -n 5 | while read -r file; do
        if [ -f "$file" ]; then
            echo "  • $(basename "$file")"
        fi
    done
}

function ideas() {
    echo "💡 Searching for blog ideas in journal..."
    /Users/ryanjohnson/dotfiles/scripts/journal.sh search "blog idea"
}

function generate() {
    local stub_name="$2"

    if [ -z "$stub_name" ]; then
        echo "Usage: blog generate <stub-name>"
        echo "Example: blog generate ai-productivity-guide"
        return 1
    fi

    # Find the stub file
    local stub_file="$POSTS_DIR/${stub_name}.md"

    if [ ! -f "$stub_file" ]; then
        echo "Error: Stub file not found: $stub_file"
        echo "Available stubs:"
        grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null | while read -r f; do
            echo "  • $(basename "$f" .md)"
        done
        return 1
    fi

    echo "🤖 Generating full content for: $stub_name"
    echo "Reading stub: $stub_file"
    echo ""

    # Extract title from the stub for context
    local title; title=$(grep -m 1 "^title:" "$stub_file" | cut -d':' -f2- | tr -d '"' | xargs)

    if [ -z "$title" ]; then
        title="$stub_name"
    fi

    echo "AI Staff: Content Specialist is creating SEO-optimized guide..."
    echo "Topic: $title"
    echo "---"

    # Call the content dispatcher with the title
    if command -v dhp-content.sh &> /dev/null; then
        dhp-content.sh "$title"
    else
        echo "Error: dhp-content.sh dispatcher not found"
        echo "Make sure bin/ is in your PATH"
        return 1
    fi

    echo ""
    echo "✅ Content generation complete"
    echo "Output saved by dispatcher to: ~/projects/ryanleej.com/content/guides/"
    echo "Next steps:"
    echo "  1. Review and edit the generated content"
    echo "  2. Move it to $POSTS_DIR/ if satisfied"
    echo "  3. Remove 'content stub' marker from original"
}

function refine() {
    local file_path="$2"

    if [ -z "$file_path" ]; then
        echo "Usage: blog refine <file-path>"
        echo "Example: blog refine $POSTS_DIR/my-post.md"
        return 1
    fi

    # Handle relative paths
    if [ ! -f "$file_path" ]; then
        # Try adding POSTS_DIR prefix
        file_path="$POSTS_DIR/$file_path"
        if [ ! -f "$file_path" ]; then
            file_path="$POSTS_DIR/${file_path}.md"
        fi
    fi

    if [ ! -f "$file_path" ]; then
        echo "Error: File not found: $file_path"
        return 1
    fi

    echo "✨ Refining content: $(basename "$file_path")"
    echo "Reading from: $file_path"
    echo ""
    echo "AI Staff: Content Specialist is polishing your draft..."
    echo "---"

    # Read the file content and pipe to content dispatcher with refine instruction
    if command -v dhp-content.sh &> /dev/null; then
        {
            echo "Please refine and improve the following blog post content. Focus on:"
            echo "- Clarity and readability"
            echo "- SEO optimization"
            echo "- Engaging headlines and structure"
            echo "- Adding relevant examples if needed"
            echo ""
            echo "Original content:"
            echo "---"
            cat "$file_path"
        } | dhp-content.sh "refine blog post"
    else
        echo "Error: dhp-content.sh dispatcher not found"
        echo "Make sure bin/ is in your PATH"
        return 1
    fi

    echo ""
    echo "✅ Content refinement complete"
    echo "Review the suggestions above and update: $file_path"
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
    ideas)
        ideas
        ;;
    generate)
        generate "$@"
        ;;
    refine)
        refine "$@"
        ;;
    *)
        echo "Usage: blog {status|stubs|random|recent|sync|ideas|generate|refine}"
        echo ""
        echo "AI-powered commands:"
        echo "  blog generate <stub-name>  - Generate full content from stub using AI"
        echo "  blog refine <file-path>    - Polish and improve existing content"
        ;;
esac
