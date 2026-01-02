#!/bin/bash
# scripts/lib/blog_lifecycle.sh
# Lifecycle management tools (Idea Sync, Versioning, Metrics, Social) for blog.sh

# --- Subcommand: ideas ---
function blog_ideas() {
    local subcommand="${1:-list}"
    shift || true

    case "$subcommand" in
        list)
            echo "💡 Content Backlog:"
            if [ -f "$BLOG_DIR/content-backlog.md" ]; then
                cat "$BLOG_DIR/content-backlog.md"
            else
                echo "  (No backlog file found at $BLOG_DIR/content-backlog.md)"
            fi
            ;;
        add)
            local idea="$*"
            if [ -z "$idea" ]; then
                echo "Usage: blog ideas add \"Your idea here\"" >&2
                return 1
            fi
            echo "- [ ] $idea" >> "$BLOG_DIR/content-backlog.md"
            echo "✅ Added to backlog: $idea"
            ;;
        sync)
            echo "🔄 Syncing ideas from journal..."
            # Simple grep for now, could be more sophisticated
            # Look for lines starting with "Idea:" or containing "#idea" in recent journal entries
            local recent_ideas
            recent_ideas=$(find "$HOME/.config/dotfiles-data/journal" -type f -mtime -7 -print0 | xargs -0 grep -h -iE "^Idea:|#idea")
            
            if [ -n "$recent_ideas" ]; then
                echo "Found recent ideas:"
                echo "$recent_ideas"
                echo ""
                echo "Add them to backlog with 'blog ideas add ...'"
            else
                echo "No recent ideas found in journal (last 7 days)."
            fi
            ;;
        *)
            echo "Usage: blog ideas <list|add|sync>"
            ;;
    esac
}

# --- Subcommand: version ---
function blog_version() {
    local subcommand="${1:-show}"
    shift || true

    case "$subcommand" in
        show)
             if [ -d "$BLOG_DIR/.git" ]; then
                local current_tag
                current_tag=$(cd "$BLOG_DIR" && git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
                echo "Current Version: $current_tag"
            else
                echo "Error: Blog directory is not a git repository." >&2
                return 1
            fi
            ;;
        history)
            if [ -d "$BLOG_DIR/.git" ]; then
                cd "$BLOG_DIR" && git log --tags --simplify-by-decoration --pretty="format:%ai %d"
            else
                echo "Error: Blog directory is not a git repository." >&2
                return 1
            fi
            ;;
        bump)
            local level="${1:-patch}"
            if [[ ! "$level" =~ ^(major|minor|patch)$ ]]; then
                echo "Usage: blog version bump <major|minor|patch>" >&2
                return 1
            fi

            if [ ! -d "$BLOG_DIR/.git" ]; then
                echo "Error: Blog directory is not a git repository." >&2
                return 1
            fi

            # Ensure git is clean
            if [ -n "$(cd "$BLOG_DIR" && git status --porcelain)" ]; then
                echo "Error: Git working directory is not clean. Commit changes first." >&2
                return 1
            fi

            local current_ver
            current_ver=$(cd "$BLOG_DIR" && git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
            # Strip 'v' prefix
            local v_num="${current_ver#v}"
            IFS='.' read -r major minor patch <<< "$v_num"

            case "$level" in
                major) major=$((major + 1)); minor=0; patch=0 ;;
                minor) minor=$((minor + 1)); patch=0 ;;
                patch) patch=$((patch + 1)) ;;
            esac

            local new_ver="v${major}.${minor}.${patch}"
            echo "Bumping version: $current_ver -> $new_ver"
            
            (
                cd "$BLOG_DIR"
                # Create an empty commit for the bump if no files changed, or just tag
                # Convention: Let's create an empty commit to mark the release
                git commit --allow-empty -m "Release $new_ver"
                git tag -a "$new_ver" -m "Version $new_ver"
            )
            echo "✅ Tagged $new_ver"
            
            # Log to journal
            if command -v journal >/dev/null; then
                 journal "Blog version bumped to $new_ver"
            fi
            ;;
        *)
            echo "Usage: blog version <show|history|bump>"
            ;;
    esac
}

# --- Subcommand: metrics ---
function blog_metrics() {
    echo "📊 Blog Metrics:"
    local total_posts
    total_posts=$(find "$POSTS_DIR" -name "*.md" | wc -l | tr -d ' ')
    echo "  • Total Posts: $total_posts"
    
    local total_words
    total_words=$(find "$POSTS_DIR" -name "*.md" -print0 | xargs -0 wc -w | tail -n 1 | awk '{print $1}')
    echo "  • Total Words: $total_words"
    
    if [ "$total_posts" -gt 0 ]; then
        local avg_words=$((total_words / total_posts))
        echo "  • Avg Words/Post: $avg_words"
    fi
}

# --- Subcommand: exemplar ---
function blog_exemplar() {
    local section="${1:-}"
    if [ -z "$section" ]; then
        echo "Usage: blog exemplar <section>"
        echo "Available sections: $(list_known_sections | tr ' ' '\n' | sort | uniq | tr '\n' ' ')"
        return 1
    fi
     
    local exemplar_rel
    if exemplar_rel=$(find_exemplar_for_section "$section"); then
        local exemplar_file="$BLOG_DIR/$exemplar_rel"
        if [ -f "$exemplar_file" ]; then
            echo "📂 Exemplar for '$section' ($exemplar_rel):"
            echo "---"
            cat "$exemplar_file"
        else
             echo "Error: Exemplar file defined but not found at $exemplar_file" >&2
             return 1
        fi
    else
        echo "No exemplar found for section '$section'." >&2
        return 1
    fi
}

# --- Subcommand: social ---
function blog_social() {
    local slug="$1"
    shift
    local platform=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --platform)
                platform="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1" >&2
                return 1
                ;;
        esac
    done
    
    if [ -z "$slug" ] || [ -z "$platform" ]; then
        echo "Usage: blog social <slug> --platform <twitter|linkedin|email>"
        return 1
    fi
    
    # Resolve file path similar to 'refine'
    local file_path="$slug"
    if [ ! -f "$file_path" ]; then
         file_path="$POSTS_DIR/$slug"
         if [ ! -f "$file_path" ]; then
             file_path="$POSTS_DIR/${slug}.md"
         fi
    fi
    
    if [ ! -f "$file_path" ]; then
        echo "Error: Post not found: $slug" >&2
        return 1
    fi
    
    echo "🤖 Generating $platform content for $(basename "$file_path")..."
    
    if command -v dhp-copy.sh &> /dev/null; then # Assuming 'copy' alias maps to dhp-copy.sh or similar
        # actually the alias is usually 'dhp-copy' or just 'copy' -> but inside scripts we should use full name if possible or the alias if sourced.
        # The quick reference says 'copy' uses 'Llama 4 Maverick'. Let's check typical script pattern. 
        # usually aliases like 'copy' are shell functions.
        # We'll try 'dhp-copy' if it exists, otherwise fall back to 'copy' command if available. 
        # Wait, the user instructions say 'dhp-chain creative narrative copy'. So 'dhp-copy' is likely the command.
        
        local copy_cmd="dhp-copy"  # Implicit assumption based on naming convention
        if ! command -v "$copy_cmd" &>/dev/null; then
             # Try finding it in bin/
             if [ -f "$HOME/dotfiles/bin/dhp-copy" ]; then
                 copy_cmd="$HOME/dotfiles/bin/dhp-copy"
             elif command -v copy &>/dev/null; then
                 copy_cmd="copy"
             else
                 echo "Error: 'dhp-copy' or 'copy' command not available." >&2
                 return 1
             fi
        fi
        
        {
            echo "Create a social media post for $platform based on this blog post."
            echo "Keep it engaging and appropriate for the platform."
            echo "---"
            cat "$file_path"
        } | "$copy_cmd" "Social media post for $platform"
        
        echo ""
        echo "✅ Generated."
    else
        echo "Error: AI copy specialist not found." >&2
        return 1
    fi
}
