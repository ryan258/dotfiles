#!/usr/bin/env bash
# gh-projects.sh - Find and recall forgotten projects from GitHub.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/common.sh"
fi

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
HELPER_SCRIPT="$DOTFILES_DIR/scripts/github_helper.sh"

if [ ! -x "$HELPER_SCRIPT" ]; then
    echo "Error: GitHub helper script not found or not executable." >&2
    exit 1
fi

# --- Subcommand: forgotten ---
function forgotten() {
    echo "🗂️  PROJECTS NOT TOUCHED IN 60+ DAYS (on GitHub):"
    
    NOW=$(date +%s)
    
    # Call helper to get repos, then parse with jq
    "$HELPER_SCRIPT" list_repos | jq -c '.[] | {name: .name, pushed_at: .pushed_at}' | while read -r repo_json; do
        
        repo_name=$(echo "$repo_json" | jq -r '.name')
        pushed_at_str=$(echo "$repo_json" | jq -r '.pushed_at')
        
        # Convert pushed_at (ISO 8601) to epoch seconds
        pushed_at_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$pushed_at_str" +%s 2>/dev/null || continue)
        
        DAYS_AGO=$(( (NOW - pushed_at_epoch) / 86400 ))
        
        if [ "$DAYS_AGO" -ge 60 ]; then
            echo "  • $repo_name ($DAYS_AGO days ago)"
        fi
    done
    
    echo ""
    echo "Run 'projects recall <name>' to see details"
}

# --- Subcommand: recall ---
function recall() {
    if [ -z "$1" ]; then
        echo "Usage: projects recall <project_name>"
        return
    fi
    
    PROJECT_NAME=$(sanitize_input "$1")
    PROJECT_NAME=${PROJECT_NAME//$'\n'/ }
    if ! [[ "$PROJECT_NAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
        echo "Error: Project name contains invalid characters." >&2
        return 1
    fi
    
    echo "📦 Project: $PROJECT_NAME"
    
    # Get repo details
    repo_details=$("$HELPER_SCRIPT" get_repo "$PROJECT_NAME")
    if [[ $(echo "$repo_details" | jq '.message == "Not Found"') == "true" ]]; then
        echo "Project '$PROJECT_NAME' not found on GitHub for user ryan258."
        return
    fi

    pushed_at_str=$(echo "$repo_details" | jq -r '.pushed_at')
    pushed_at_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$pushed_at_str" +%s 2>/dev/null || echo "$NOW")
    NOW=$(date +%s)
    DAYS_AGO=$(( (NOW - pushed_at_epoch) / 86400 ))
    echo "Last push: $DAYS_AGO days ago"

    # Get latest commit
    latest_commit=$("$HELPER_SCRIPT" get_latest_commit "$PROJECT_NAME")
    commit_message=$(echo "$latest_commit" | jq -r '.commit.message | split("\n")[0]')
    echo "Last commit: \"$commit_message\""

    # Get README
    readme_content=$("$HELPER_SCRIPT" get_readme_content "$PROJECT_NAME")
    if [ -n "$readme_content" ]; then
        echo "README preview:"
        echo "$readme_content" | head -n 5 | sed 's/^/  /'
    fi
    
    html_url=$(echo "$repo_details" | jq -r '.html_url')
    echo "URL: $html_url"
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
