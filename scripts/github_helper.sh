#!/bin/bash
# github_helper.sh - Functions for interacting with the GitHub API
set -euo pipefail

# --- Configuration ---
DOTFILES_ENV="$HOME/dotfiles/.env"
if [ -f "$DOTFILES_ENV" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$DOTFILES_ENV"
    set +a
fi

TOKEN_FILE="$HOME/.github_token"
TOKEN_FALLBACK="$HOME/.config/dotfiles-data/github_token"
CACHE_DIR="$HOME/.config/dotfiles-data/cache/github"
CACHE_AVAILABLE=true
if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
    CACHE_AVAILABLE=false
fi

GIT_USERNAME=$(git config user.name 2>/dev/null || true)
USERNAME="${GITHUB_USERNAME:-${GIT_USERNAME}}"
if [ -z "$USERNAME" ]; then
    echo "Error: GITHUB_USERNAME not set and git config user.name not found" >&2
    exit 1
fi

get_file_perms() {
    local file="$1"
    if stat -f %A "$file" >/dev/null 2>&1; then
        stat -f %A "$file"
    else
        stat -c %a "$file"
    fi
}

ensure_token_access() {
    local source_file="$1"
    local fallback_file="$2"

    if [ -f "$source_file" ]; then
        local current_perms
        current_perms=$(get_file_perms "$source_file")
        if [ "$current_perms" != "600" ]; then
            if chmod 600 "$source_file" 2>/dev/null; then
                echo "Adjusted permissions on $source_file (was $current_perms, now 600)." >&2
                echo "$source_file"
                return
            fi

            local fallback_dir
            fallback_dir=$(dirname "$fallback_file")
            if [ ! -d "$fallback_dir" ]; then
                mkdir -p "$fallback_dir" 2>/dev/null || true
            fi
            if [ -w "$fallback_dir" ] 2>/dev/null; then
                if contents=$(cat "$source_file" 2>/dev/null); then
                    if printf "%s" "$contents" > "$fallback_file" 2>/dev/null && chmod 600 "$fallback_file" 2>/dev/null; then
                        echo "Copied GitHub token to $fallback_file with secure permissions." >&2
                        echo "$fallback_file"
                        return
                    fi
                fi
            fi

            echo "Warning: Unable to apply secure permissions to $source_file (current perms: $current_perms)." >&2
            echo "Please run: chmod 600 \"$source_file\" (continuing with existing permissions)." >&2
            echo "$source_file"
            return
        fi
        echo "$source_file"
        return
    fi

    if [ -f "$fallback_file" ]; then
        echo "$fallback_file"
        return
    fi

    echo ""
}

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

TOKEN=$(cat "$TOKEN_PATH")

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

_github_api_call() {
    local endpoint="$1"
    local api_url="https://api.github.com$endpoint"
    local cache_file; cache_file=$(_cache_path_for "$endpoint")

    if response=$(curl -fsS -H "Authorization: token $TOKEN" \
         -H "Accept: application/vnd.github.v3+json" \
         "$api_url" 2>/dev/null); then
        if [ -n "$cache_file" ]; then
            printf "%s" "$response" > "$cache_file"
        fi
        printf "%s" "$response"
    else
        if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
            echo "Warning: Unable to reach GitHub. Serving cached data for $endpoint." >&2
            cat "$cache_file"
        else
            echo "Error: Failed to reach GitHub for $endpoint." >&2
            return 1
        fi
    fi
}

list_repos() {
    _github_api_call "/users/$USERNAME/repos?sort=pushed&per_page=100"
}

get_repo() {
    local repo_name="$1"
    _github_api_call "/repos/$USERNAME/$repo_name"
}

get_latest_commit() {
    local repo_name="$1"
    _github_api_call "/repos/$USERNAME/$repo_name/commits?per_page=1" | jq '.[0]'
}

get_readme_content() {
    local repo_name="$1"
    _github_api_call "/repos/$USERNAME/$repo_name/readme" | jq -r '.content' | base64 --decode
}

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
