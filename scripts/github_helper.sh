#!/usr/bin/env bash
# github_helper.sh - Functions for interacting with the GitHub API
#
# This script serves as a wrapper for GitHub API calls, handling authentication,
# caching, and basic error recovery. It is primarily used by startday.sh
# to display recent activity from the user's repositories.

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/config.sh"
elif [ -f "$DOTFILES_DIR/scripts/lib/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$DOTFILES_DIR/scripts/lib/config.sh"
else
    echo "Error: configuration library not found at $SCRIPT_DIR/lib/config.sh or $DOTFILES_DIR/scripts/lib/config.sh" >&2
    exit 1
fi

# Define locations for the GitHub Personal Access Token (PAT).
# TOKEN_FILE: The primary expected location for the token.
# TOKEN_FALLBACK: A secondary/backup location (often in synced dotfiles data).
TOKEN_FILE="$GITHUB_TOKEN_FILE"
TOKEN_FALLBACK="$GITHUB_TOKEN_FALLBACK"

# Setup local caching directory.
# Caching prevents API rate limits and speeds up execution when offline or on slow networks.
CACHE_DIR="$GITHUB_CACHE_DIR"
CACHE_AVAILABLE=true
if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
    CACHE_AVAILABLE=false
fi

# Optional diagnostics and request timeout controls.
GITHUB_DEBUG="${GITHUB_DEBUG:-false}"
GITHUB_CONNECT_TIMEOUT="${GITHUB_CONNECT_TIMEOUT:-5}"
GITHUB_REQUEST_TIMEOUT="${GITHUB_REQUEST_TIMEOUT:-20}"

# Determine GitHub Username:
# 1. Try env var GITHUB_USERNAME (explicit override).
# 2. Fallback to git config user.name (git default).
GIT_USERNAME=$(git config user.name 2>/dev/null || true)
USERNAME="${GITHUB_USERNAME:-${GIT_USERNAME}}"
if [ -z "$USERNAME" ]; then
    echo "Error: GITHUB_USERNAME not set and git config user.name not found" >&2
    exit 1
fi
if [ -z "${GITHUB_USERNAME:-}" ] && [[ "$USERNAME" == *" "* ]]; then
    echo "Error: GITHUB_USERNAME not set and git config user.name looks like a full name ('$USERNAME'). Set GITHUB_USERNAME in .env." >&2
    exit 1
fi

# Ensure the token file has secure permissions (600 - read/write only by owner).
# If the primary file is insecure, it attempts to fix it in place or safely copy it to the fallback location.
# usage: ensure_token_access <source_path> <fallback_path>
ensure_token_access() {
    local source_file="$1"
    local fallback_file="$2"

    if [ -f "$source_file" ]; then
        # Try to secure it, but don't block if we can't
        if ! chmod 600 "$source_file" 2>/dev/null; then
             # Just warn and proceed
             echo "Warning: Unable to secure $source_file permissions." >&2
        fi
        echo "$source_file"
        return
    fi

    if [ -f "$fallback_file" ]; then
        if ! chmod 600 "$fallback_file" 2>/dev/null; then
             echo "Warning: Unable to secure $fallback_file permissions." >&2
        fi
        echo "$fallback_file"
        return
    fi

    # No valid token file found
    echo ""
}

# --- Initialization & Dependency Checks ---

TOKEN_PATH=$(ensure_token_access "$TOKEN_FILE" "$TOKEN_FALLBACK")

# Use environment variable if file not found
if [ -z "$TOKEN_PATH" ]; then
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        TOKEN="$GITHUB_TOKEN"
    else
        echo "Error: GitHub token not found. Set GITHUB_TOKEN in .env or create $TOKEN_FILE." >&2
        exit 1
    fi
else
    # Load the token into memory for use in requests
    TOKEN=$(cat "$TOKEN_PATH") 
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is not installed. Please install it." >&2
    exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is not installed. Please install it with 'brew install jq'." >&2
    exit 1
fi



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

_github_debug_log() {
    if [ "$GITHUB_DEBUG" = "true" ]; then
        echo "$*" >&2
    fi
}

# Convert a local calendar day (YYYY-MM-DD) into an inclusive/exclusive UTC window.
# Output (4 lines): utc_start_iso, utc_end_iso, utc_start_epoch, utc_end_epoch
_utc_window_for_local_date() {
    local target_date="$1"

    if command -v python3 >/dev/null 2>&1; then
        if ! python3 - "$target_date" <<'PY'
import sys
from datetime import datetime, timedelta, timezone

target = sys.argv[1]

try:
    start_local = datetime.strptime(target, "%Y-%m-%d")
except ValueError:
    sys.exit(1)
end_local = start_local + timedelta(days=1)

start_epoch = int(start_local.timestamp())
end_epoch = int(end_local.timestamp())
start_utc = datetime.fromtimestamp(start_epoch, timezone.utc)
end_utc = datetime.fromtimestamp(end_epoch, timezone.utc)

print(start_utc.strftime("%Y-%m-%dT%H:%M:%SZ"))
print(end_utc.strftime("%Y-%m-%dT%H:%M:%SZ"))
print(start_epoch)
print(end_epoch)
PY
        then
            return 1
        fi
        return
    fi

    local start_epoch
    local end_epoch

    if date -j -f "%Y-%m-%d %H:%M:%S" "$target_date 00:00:00" "+%s" >/dev/null 2>&1; then
        start_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$target_date 00:00:00" "+%s") || return 1
    elif command -v gdate >/dev/null 2>&1; then
        start_epoch=$(gdate -d "$target_date 00:00:00" +%s) || return 1
    else
        start_epoch=$(date -d "$target_date 00:00:00" +%s) || return 1
    fi
    end_epoch=$((start_epoch + 86400))

    local start_utc
    local end_utc
    if date -u -r "$start_epoch" "+%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
        start_utc=$(date -u -r "$start_epoch" "+%Y-%m-%dT%H:%M:%SZ") || return 1
        end_utc=$(date -u -r "$end_epoch" "+%Y-%m-%dT%H:%M:%SZ") || return 1
    elif command -v gdate >/dev/null 2>&1; then
        start_utc=$(gdate -u -d "@$start_epoch" "+%Y-%m-%dT%H:%M:%SZ") || return 1
        end_utc=$(gdate -u -d "@$end_epoch" "+%Y-%m-%dT%H:%M:%SZ") || return 1
    else
        start_utc=$(date -u -d "@$start_epoch" "+%Y-%m-%dT%H:%M:%SZ") || return 1
        end_utc=$(date -u -d "@$end_epoch" "+%Y-%m-%dT%H:%M:%SZ") || return 1
    fi

    printf "%s\n%s\n%s\n%s\n" "$start_utc" "$end_utc" "$start_epoch" "$end_epoch"
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

    local tmp_response
    local primary_err
    local fallback_err
    local header_file
    local fallback_attempted=false
    tmp_response=$(mktemp -t "gh_api.XXXXXX")
    primary_err=$(mktemp -t "gh_api_primary_err.XXXXXX")
    fallback_err=$(mktemp -t "gh_api_fallback_err.XXXXXX")
    header_file="${tmp_response}.headers"

    # Optional scope diagnostics when debugging auth issues.
    if [ "$GITHUB_DEBUG" = "true" ] && \
       curl -fsS -L -I \
            --connect-timeout "$GITHUB_CONNECT_TIMEOUT" \
            --max-time "$GITHUB_REQUEST_TIMEOUT" \
            -H "Authorization: token $TOKEN" \
            "$api_url" > "$header_file" 2>/dev/null; then
        _github_debug_log "Scopes: $(grep -i '^x-oauth-scopes:' "$header_file" | tr -d '\r' || echo "(none)")"
    fi

    if curl -fsS -L \
         --connect-timeout "$GITHUB_CONNECT_TIMEOUT" \
         --max-time "$GITHUB_REQUEST_TIMEOUT" \
         -H "Authorization: token $TOKEN" \
         -H "Accept: application/vnd.github.v3+json" \
         "$api_url" -o "$tmp_response" 2>"$primary_err"; then

        # Validate JSON strictly
        if jq empty "$tmp_response" >/dev/null 2>&1; then
            if [ -n "$cache_file" ]; then
                cp "$tmp_response" "$cache_file"
            fi
            cat "$tmp_response"
            rm -f "$tmp_response" "$primary_err" "$fallback_err" "$header_file"
            return 0
        fi
    fi

    # Public user endpoints should still work without auth.
    if [[ "$endpoint" =~ ^/users/[^/]+/(events|repos)(\?|$) ]]; then
        fallback_attempted=true
        if curl -fsS -L \
             --connect-timeout "$GITHUB_CONNECT_TIMEOUT" \
             --max-time "$GITHUB_REQUEST_TIMEOUT" \
             -H "Accept: application/vnd.github.v3+json" \
             "$api_url" -o "$tmp_response" 2>"$fallback_err"; then

            if jq empty "$tmp_response" >/dev/null 2>&1; then
                if [ -n "$cache_file" ]; then
                    cp "$tmp_response" "$cache_file"
                fi
                cat "$tmp_response"
                rm -f "$tmp_response" "$primary_err" "$fallback_err" "$header_file"
                return 0
            fi
            _github_debug_log "Invalid JSON from unauthenticated fallback for $endpoint"
        fi
    fi

    if [ "$GITHUB_DEBUG" = "true" ]; then
        _github_debug_log "Debug Warning: All fetch attempts failed for $endpoint"
        if [ -s "$primary_err" ]; then
            _github_debug_log "Primary Err: $(head -n 1 "$primary_err" | tr -d '\r')"
        fi
        if [ "$fallback_attempted" = true ] && [ -s "$fallback_err" ]; then
            _github_debug_log "Fallback Err: $(head -n 1 "$fallback_err" | tr -d '\r')"
        fi
    fi

    # On failure, try fallback to cache.
    if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
        echo "Warning: Unable to reach GitHub. Serving cached data for $endpoint." >&2
        cat "$cache_file"
        rm -f "$tmp_response" "$primary_err" "$fallback_err" "$header_file"
        return 0
    fi

    rm -f "$tmp_response" "$primary_err" "$fallback_err" "$header_file"
    echo "Error: Failed to reach GitHub for $endpoint." >&2
    return 1
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

    if [ "${GITHUB_EXCLUDE_REPOS:-}" ]; then
        # Use jq to parse the comma-separated list and filter
        # We use --arg to pass the environment variable safely
        printf "%s" "$json_data" | jq --arg exclude "$GITHUB_EXCLUDE_REPOS" \
            "(\$exclude | split(\",\") | map(gsub(\"^[[:space:]]+|[[:space:]]+$\";\"\"))) as \$ex_list | $filter | map(select(.name as \$n | \$ex_list | index(\$n) | not))"
    else
        printf "%s" "$json_data" | jq "$filter"
    fi
}


# Lists recent events for the authenticated user, with fallback to public events.
list_user_events() {
    {
        # Suppress stderr from primary call
        if ! _github_api_call "/user/events?per_page=100" 2>/dev/null; then
            # If primary failed, try fallback
            _github_api_call "/users/$USERNAME/events?per_page=100" || {
                 echo "Error: Failed to fetch user events" >&2
                 return 1
            }
        fi
    } | iconv -c -f utf-8 -t utf-8
}

# Lists commits for a specific date (YYYY-MM-DD) by querying the Commits API.
# Lists commits for a specific date (YYYY-MM-DD) using a hybrid approach:
# 1. Events API tells us which repos/branches were pushed on the target date
# 2. Commits API fetches the actual commit details for those branches
list_commits_for_date() {
    local target_date="$1"
    if [ -z "$target_date" ]; then
        echo "Usage: list_commits_for_date YYYY-MM-DD" >&2
        return 1
    fi

    if [[ ! "$target_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "Usage: list_commits_for_date YYYY-MM-DD" >&2
        return 1
    fi

    local window_data
    if ! window_data=$(_utc_window_for_local_date "$target_date"); then
        echo "Error: Failed to compute date window for $target_date" >&2
        return 1
    fi
    local utc_start
    local utc_end
    local utc_start_epoch
    local utc_end_epoch
    utc_start=$(echo "$window_data" | sed -n '1p')
    utc_end=$(echo "$window_data" | sed -n '2p')
    utc_start_epoch=$(echo "$window_data" | sed -n '3p')
    utc_end_epoch=$(echo "$window_data" | sed -n '4p')

    # Get PushEvents to find which repos/branches were pushed on target date
    local events_json
    events_json=$(list_user_events 2>/dev/null) || return 1

    # Extract unique repo/branch pairs from PushEvents on the local day window.
    local repo_branches
    repo_branches=$(echo "$events_json" | jq -r --argjson start "$utc_start_epoch" --argjson end "$utc_end_epoch" '
        [.[] | select(.type == "PushEvent" and ((try (.created_at | fromdateiso8601) catch 0) >= $start) and ((try (.created_at | fromdateiso8601) catch 0) < $end))] |
        .[] | (.repo.name | split("/")[1]) + ":" + ((.payload.ref // "refs/heads/HEAD") | split("/")[-1])
    ' 2>/dev/null | sort -u)

    [ -z "$repo_branches" ] && return 0

    local all_commits=""

    # For each repo/branch, query the Commits API
    while IFS=: read -r repo_name branch; do
        [ -z "$repo_name" ] && continue
        [ -z "$branch" ] && branch="HEAD"

        local commits_json
        commits_json=$(_github_api_call "/repos/$USERNAME/$repo_name/commits?sha=$branch&author=$USERNAME&since=${utc_start}&until=${utc_end}&per_page=20" 2>/dev/null) || continue

        local parsed_commits
        parsed_commits=$(echo "$commits_json" | jq -r --arg repo "$repo_name" '
            if type == "array" then
                .[] | ($repo) + "|" + (.sha[:7]) + "|" + (.commit.message | split("\n")[0] | gsub("\\|"; "/"))
            else empty end
        ' 2>/dev/null || true)

        if [ -n "$parsed_commits" ]; then
            all_commits+="${parsed_commits}"$'\n'
        fi
    done <<< "$repo_branches"

    if [ -n "$all_commits" ]; then
        printf "%s" "$all_commits" | awk 'NF' | sort -u
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
COMMAND="${1:-}"

case "$COMMAND" in
    list_repos)
        list_repos
        ;;
    get_repo)
        shift
        if [ -z "${1:-}" ]; then
            echo "Usage: $0 get_repo <repo>" >&2
            exit 1
        fi
        get_repo "$@"
        ;;
    get_latest_commit)
        shift
        if [ -z "${1:-}" ]; then
            echo "Usage: $0 get_latest_commit <repo>" >&2
            exit 1
        fi
        get_latest_commit "$@"
        ;;
    get_readme_content)
        shift
        if [ -z "${1:-}" ]; then
            echo "Usage: $0 get_readme_content <repo>" >&2
            exit 1
        fi
        get_readme_content "$@"
        ;;
    list_user_events)
        list_user_events
        ;;
    list_commits_for_date)
        shift
        if [ -z "${1:-}" ]; then
            echo "Usage: $0 list_commits_for_date YYYY-MM-DD" >&2
            exit 1
        fi
        list_commits_for_date "$@"
        ;;
    *)
        echo "Usage: $0 {list_repos|get_repo <repo>|get_latest_commit <repo>|get_readme_content <repo>|list_user_events|list_commits_for_date YYYY-MM-DD}" >&2
        exit 1
        ;;
esac
