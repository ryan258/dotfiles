#!/usr/bin/env bash
# dhp-context.sh: Context Injection Library for AI Dispatchers
# Source this file to gather local context for AI prompts
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_DHP_CONTEXT_LOADED:-}" ]]; then
    return 0
fi
readonly _DHP_CONTEXT_LOADED=true

# This script provides functions to gather relevant context:
# - gather_context() - Main function to collect all context
# - get_recent_journal() - Last N journal entries
# - get_active_todos() - Current todo list
# - get_git_context() - Recent commits and repo info
# - get_project_readme() - README from current directory

DHP_CONTEXT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$DHP_CONTEXT_DIR/.." && pwd)}"

if [[ -f "$DOTFILES_DIR/scripts/lib/config.sh" ]]; then
    # shellcheck disable=SC1090
    source "$DOTFILES_DIR/scripts/lib/config.sh"
else
    echo "Error: configuration library not found at $DOTFILES_DIR/scripts/lib/config.sh" >&2
    return 1
fi

if [[ -z "${TODO_FILE:-}" || -z "${JOURNAL_FILE:-}" ]]; then
    echo "Error: TODO_FILE and JOURNAL_FILE must be set by config.sh." >&2
    return 1
fi

# redact_sensitive_info: Redacts common sensitive patterns from a string.
# Usage: redact_sensitive_info <input_string>
redact_sensitive_info() {
    local input="$1"
    local redacted_output="$input"

    # Redact common API key patterns (e.g., sk-...)
    redacted_output=$(echo "$redacted_output" | sed -E 's/sk-[A-Za-z0-9]{32,}/[REDACTED_API_KEY]/g')
    # Redact email addresses
    redacted_output=$(echo "$redacted_output" | sed -E 's/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/[REDACTED_EMAIL]/g')
    # Redact SSN-like patterns (XXX-XX-XXXX)
    redacted_output=$(echo "$redacted_output" | sed -E 's/[0-9]{3}-[0-9]{2}-[0-9]{4}/[REDACTED_SSN]/g')
    # Redact common password keywords followed by potential passwords (simple, not exhaustive)
    redacted_output=$(echo "$redacted_output" | sed -E 's/(password|passwd|secret|token|key)[[:space:]]*[:=][[:space:]]*[^[:space:]]+/[REDACTED_CREDENTIAL]/gi')

    echo "$redacted_output"
}

# Get recent journal entries
# Usage: get_recent_journal [days]
get_recent_journal() {
    local days="${1:-3}"
    local cutoff_date

    if [ ! -f "$JOURNAL_FILE" ]; then
        echo ""
        return
    fi

    # Calculate cutoff date
    cutoff_date=$(date -v-"${days}"d "+%Y-%m-%d" 2>/dev/null || date -d "${days} days ago" "+%Y-%m-%d" 2>/dev/null)

    # Extract recent entries
    awk -F'|' -v cutoff="$cutoff_date" 'NF>=2 { if (substr($1,1,10) >= cutoff) print }' "$JOURNAL_FILE" 2>/dev/null | tail -20
}

# Get active todo items
# Usage: get_active_todos [limit]
get_active_todos() {
    local limit="${1:-10}"

    if [ ! -f "$TODO_FILE" ]; then
        echo ""
        return
    fi

    head -n "$limit" "$TODO_FILE" 2>/dev/null
}

# Get git context
# Usage: get_git_context [commit_count]
get_git_context() {
    local commit_count="${1:-10}"
    local context=""

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo ""
        return
    fi

    # Repository name
    local repo_name
    repo_name=$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null)
    context+="Repository: $repo_name\n"

    # Current branch
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    context+="Branch: $branch\n"

    # Recent commits
    local commits
    commits=$(git log --oneline -n "$commit_count" 2>/dev/null)
    if [ -n "$commits" ]; then
        context+="\nRecent commits:\n$commits\n"
    fi

    # Uncommitted changes summary
    if ! git diff --quiet 2>/dev/null; then
        local files_changed
        files_changed=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
        context+="\nUncommitted changes: $files_changed files\n"
    fi

    echo -e "$context"
}

# Get project README
# Usage: get_project_readme
get_project_readme() {
    local readme=""

    # Try to find README in current dir or git root
    if [ -f "README.md" ]; then
        readme=$(head -n 50 "README.md" 2>/dev/null)
    elif git rev-parse --git-dir > /dev/null 2>&1; then
        local git_root
        git_root=$(git rev-parse --show-toplevel 2>/dev/null)
        if [ -f "$git_root/README.md" ]; then
            readme=$(head -n 50 "$git_root/README.md" 2>/dev/null)
        fi
    fi

    if [ -n "$readme" ]; then
        echo "Project README (first 50 lines):"
        echo "$readme"
    fi
}

# Get blog context (if in blog directory)
# Usage: get_blog_context
get_blog_context() {
    local context=""

    # Check if we're in a blog directory
    if [[ "$(pwd)" == *"blog"* ]] || [[ "$(pwd)" == *"ryanleej"* ]]; then
        # Get recent blog topics from stubs
        if [ -n "${BLOG_DIR:-}" ] && [ -d "${BLOG_DIR}/content" ]; then
            local recent_posts
            recent_posts=$(find "${BLOG_DIR}/content" -name "*.md" -type f -mtime -30 2>/dev/null | head -5)
            if [ -n "$recent_posts" ]; then
                context+="Recent blog posts (last 30 days):\n"
                while IFS= read -r post; do
                    local title
                    title=$(grep -m1 "^title:" "$post" 2>/dev/null | cut -d'"' -f2)
                    context+="  - $title\n"
                done <<< "$recent_posts"
            fi
        fi
    fi

    echo -e "$context"
}

# Main context gathering function
# Usage: gather_context [--full|--minimal]
gather_context() {
    local mode="${1:---minimal}"
    local context=""

    context+="=== LOCAL CONTEXT ===\n\n"

    # Always include current directory
    context+="Current directory: $(pwd)\n"
    context+="Current date: $(date '+%Y-%m-%d %H:%M')\n\n"

    if [ "$mode" = "--full" ]; then
        # Full context mode: include everything

        # Git context
        local git_ctx
        git_ctx=$(get_git_context 10)
        if [ -n "$git_ctx" ]; then
            context+="--- Git Context ---\n"
            context+="$git_ctx\n"
        fi

        # Active todos
        local todos
        todos=$(get_active_todos 10)
        if [ -n "$todos" ]; then
            context+="--- Active Tasks (Top 10) ---\n"
            context+="$todos\n\n"
        fi

        # Recent journal
        local journal
        journal=$(get_recent_journal 3)
        if [ -n "$journal" ]; then
            context+="--- Recent Journal (Last 3 Days) ---\n"
            context+="$journal\n\n"
        fi

        # Project README
        local readme
        readme=$(get_project_readme)
        if [ -n "$readme" ]; then
            context+="--- $readme ---\n\n"
        fi

        # Blog context
        local blog_ctx
        blog_ctx=$(get_blog_context)
        if [ -n "$blog_ctx" ]; then
            context+="--- Blog Context ---\n"
            context+="$blog_ctx\n"
        fi

    else
        # Minimal context mode: just git and top tasks

        # Git context (fewer commits)
        local git_ctx
        git_ctx=$(get_git_context 5)
        if [ -n "$git_ctx" ]; then
            context+="$git_ctx\n"
        fi

        # Top 3 todos
        local todos
        todos=$(get_active_todos 3)
        if [ -n "$todos" ]; then
            context+="Top tasks:\n"
            context+="$todos\n\n"
        fi
    fi

    context+="=== END CONTEXT ===\n"

    # Redact sensitive information before outputting
    context=$(redact_sensitive_info "$context")

    echo -e "$context"
}

# Export functions if sourced
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    export -f get_recent_journal
    export -f get_active_todos
    export -f get_git_context
    export -f get_project_readme
    export -f get_blog_context
    export -f gather_context
fi
