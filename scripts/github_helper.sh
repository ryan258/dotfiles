#!/bin/bash
# github_helper.sh - Functions for interacting with the GitHub API
#
# This script serves as a wrapper for GitHub API calls, handling authentication,
# caching, and basic error recovery. It is primarily used by startday.sh
# to display recent activity from the user's repositories.

set -euo pipefail

# --- Configuration ---
# Load environment variables from dotfiles configuration if present.
# This allows for setting variables like GITHUB_USERNAME or other context
# from the centralized .env file.
DOTFILES_ENV="$HOME/dotfiles/.env"
if [ -f "$DOTFILES_ENV" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$DOTFILES_ENV"
    set +a
fi

# Define locations for the GitHub Personal Access Token (PAT).
# TOKEN_FILE: The primary expected location for the token.
# TOKEN_FALLBACK: A secondary/backup location (often in synced dotfiles data).
TOKEN_FILE="$HOME/.github_token"
TOKEN_FALLBACK="$HOME/.config/dotfiles-data/github_token"

# Setup local caching directory.
# Caching prevents API rate limits and speeds up execution when offline or on slow networks.
CACHE_DIR="$HOME/.config/dotfiles-data/cache/github"
CACHE_AVAILABLE=true
if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
    CACHE_AVAILABLE=false
fi

# Determine GitHub Username:
# 1. Try env var GITHUB_USERNAME (explicit override).
# 2. Fallback to git config user.name (git default).
GIT_USERNAME=$(git config user.name 2>/dev/null || true)
USERNAME="${GITHUB_USERNAME:-${GIT_USERNAME}}"
if [ -z "$USERNAME" ]; then
    echo "Error: GITHUB_USERNAME not set and git config user.name not found" >&2
    exit 1
fi

# Helper to get file permissions in a cross-platform way.
# Handles differences between BSD stat (macOS) and GNU stat (Linux).
get_file_perms() {
    local file="$1"
    if stat -f %A "$file" >/dev/null 2>&1; then
        # BSD stat (macOS) output (e.g., 600)
        stat -f %A "$file"
    else
        # GNU stat (Linux) output (e.g., 600)
        stat -c %a "$file"
    fi
}

# Ensure the token file has secure permissions (600 - read/write only by owner).
# If the primary file is insecure, it attempts to fix it in place or safely copy it to the fallback location.
# usage: ensure_token_access <source_path> <fallback_path>
ensure_token_access() {
    local source_file="$1"
    local fallback_file="$2"

    if [ -f "$source_file" ]; then
        local current_perms
        current_perms=$(get_file_perms "$source_file")
        
        # Check for strict permissions (600)
        if [ "$current_perms" != "600" ]; then
            # Attempt to fix permissions in place
            if chmod 600 "$source_file" 2>/dev/null; then
                echo "Adjusted permissions on $source_file (was $current_perms, now 600)." >&2
                echo "$source_file"
                return
            fi

            # If we can't chmod (filesystem issues?), try to copy safely to fallback
            local fallback_dir
            fallback_dir=$(dirname "$fallback_file")
            if [ ! -d "$fallback_dir" ]; then
                mkdir -p "$fallback_dir" 2>/dev/null || true
            fi
            
            # If fallback dir is writable, copy and secure
            if [ -w "$fallback_dir" ] 2>/dev/null; then
                if contents=$(cat "$source_file" 2>/dev/null); then
                    if printf "%s" "$contents" > "$fallback_file" 2>/dev/null && chmod 600 "$fallback_file" 2>/dev/null; then
                        echo "Copied GitHub token to $fallback_file with secure permissions." >&2
                        echo "$fallback_file"
                        return
                    fi
                fi
            fi

            # If all fixes fail, warn user but return original path (better to run insecurely than crash)
            echo "Warning: Unable to apply secure permissions to $source_file (current perms: $current_perms)." >&2
            echo "Please run: chmod 600 \"$source_file\" (continuing with existing permissions)." >&2
            echo "$source_file"
            return
        fi
        
        # File exists and has correct permissions
        echo "$source_file"
        return
    fi

    # Source does not exist, check fallback
    if [ -f "$fallback_file" ]; then
        echo "$fallback_file"
        return
    fi

    # No valid token file found
    echo ""
}

# --- Initialization & Dependency Checks ---

TOKEN_PATH=$(ensure_token_access "$TOKEN_FILE" "$TOKEN_FALLBACK")
if [ -z "$TOKEN_PATH" ]; then
    echo "Error: GitHub token not found. Create $TOKEN_FILE (or $TOKEN_FALLBACK) with your PAT." >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is not installed. Please install it." >&2
    exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is not installed. Please install it with 'brew install jq'." >&2
    exit 1
fi

# Load the token into memory for use in requests
TOKEN=$(cat "$TOKEN_PATH")

# --- Internal Helper Functions ---

# Generates a safe filename for caching API responses based on the endpoint URL.
# Replaces special characters (/ : ? & =) with underscores or dashes.
_cache_path_for() {
    local endpoint="$1"
    local safe_endpoint
    safe_endpoint=$(echo "$endpoint" | tr '/:?&=' '__--')
    if [ "$CACHE_AVAILABLE" = true ]; then
        echo "$CACHE_DIR/${safe_endpoint}.json"
    else
        echo ""
    fi
}

# Core API caller.
# 1. Constructs full URL.
# 2. Authenticates using Bearer token.
# 3. Saves success responses to cache.
# 4. Serves from cache if network call fails.
_github_api_call() {
    local endpoint="$1"
    local api_url="https://api.github.com$endpoint"
    local cache_file; cache_file=$(_cache_path_for "$endpoint")

    # Try live fetch
    if response=$(curl -fsS -H "Authorization: token $TOKEN" \
         -H "Accept: application/vnd.github.v3+json" \
         "$api_url" 2>/dev/null); then
        # On success, update cache
        if [ -n "$cache_file" ]; then
            printf "%s" "$response" > "$cache_file"
        fi
        printf "%s" "$response"
    else
        # On failure, try fallback to cache
        if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
            echo "Warning: Unable to reach GitHub. Serving cached data for $endpoint." >&2
            cat "$cache_file"
        else
            echo "Error: Failed to reach GitHub for $endpoint." >&2
            return 1
        fi
    fi
}

# --- Public Interface Functions ---

# Lists all repositories for the configured user, sorted by most recently pushed.
# Fetches up to 100 repositories.
list_repos() {
    local json_data
    if ! json_data=$(_github_api_call "/users/$USERNAME/repos?sort=pushed&per_page=100"); then
        echo "Error: Failed to fetch repositories" >&2
        return 1
    fi

    local filter="."

    if [ "${GITHUB_EXCLUDE_FORKS:-false}" = "true" ]; then
        filter+=" | map(select(.fork == false))"
    fi

    if [ -n "${GITHUB_EXCLUDE_REPOS:-}" ]; then
        # Use jq to parse the comma-separated list and filter
        # We use --arg to pass the environment variable safely
        echo "$json_data" | jq --arg exclude "$GITHUB_EXCLUDE_REPOS" \
            "(\$exclude | split(\",\") | map(gsub(\"^\\s+|\\s+$\";\"\"))) as \$ex_list | $filter | map(select(.name as \$n | \$ex_list | index(\$n) | not))"
    else
        echo "$json_data" | jq "$filter"
    fi
}

# Gets raw JSON data for a specific repository.
get_repo() {
    local repo_name="$1"
    _github_api_call "/repos/$USERNAME/$repo_name"
}

# Gets the single most recent commit for a repository.
get_latest_commit() {
    local repo_name="$1"
    _github_api_call "/repos/$USERNAME/$repo_name/commits?per_page=1" | jq '.[0]'
}

# Fetches the README content for a repository and decodes it from Base64.
get_readme_content() {
    local repo_name="$1"
    _github_api_call "/repos/$USERNAME/$repo_name/readme" | jq -r '.content' | base64 --decode
}

# --- Main Execution ---

# Parse command line arguments to route to the correct function header.
case "$1" in
    list_repos)
        list_repos
        ;;
    get_repo)
        shift
        get_repo "$@"
        ;;
    get_latest_commit)
        shift
        get_latest_commit "$@"
        ;;
    get_readme_content)
        shift
        get_readme_content "$@"
        ;;
    *)
        echo "Usage: $0 {list_repos|get_repo <repo>|get_latest_commit <repo>|get_readme_content <repo>}" >&2
        exit 1
        ;;
esac
