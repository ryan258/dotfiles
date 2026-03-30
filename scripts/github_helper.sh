#!/usr/bin/env bash
# github_helper.sh - Functions for interacting with the GitHub API
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
#
# This script serves as a wrapper for GitHub API calls, handling authentication,
# caching, and basic error recovery. It is primarily used by startday.sh
# to display recent activity from the user's repositories.


# --- Configuration ---
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

if [ -f "$SCRIPT_DIR/lib/date_utils.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/date_utils.sh"
elif [ -f "$DOTFILES_DIR/scripts/lib/date_utils.sh" ]; then
    # shellcheck disable=SC1090
    source "$DOTFILES_DIR/scripts/lib/date_utils.sh"
else
    echo "Error: date utilities not found at $SCRIPT_DIR/lib/date_utils.sh or $DOTFILES_DIR/scripts/lib/date_utils.sh" >&2
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

_commit_activity_cache_path_for_date() {
    local target_date="$1"

    _cache_path_for "/graphql/commit-activity?user=$USERNAME&date=$target_date"
}

_restore_commit_activity_cache() {
    local cache_file="$1"
    local target_date="$2"
    local destination="$3"

    if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
        echo "Warning: Unable to refresh GitHub commit activity for $target_date. Serving cached data." >&2
        cp "$cache_file" "$destination"
        return 0
    fi

    return 1
}

_github_debug_log() {
    if [ "$GITHUB_DEBUG" = "true" ]; then
        echo "$*" >&2
    fi
}

# Convert a local calendar day (YYYY-MM-DD) into an inclusive/exclusive UTC window.
# End boundary is computed from next local midnight to correctly handle DST days.
# Output (4 lines): utc_start_iso, utc_end_iso, utc_start_epoch, utc_end_epoch
_utc_window_for_local_date() {
    local target_date="$1"

    if ! [[ "$target_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        return 1
    fi

    local start_epoch
    start_epoch=$(date_shift_from "$target_date" 0 "%s") || return 1
    if ! [[ "$start_epoch" =~ ^-?[0-9]+$ ]]; then
        return 1
    fi

    local end_epoch
    end_epoch=$(date_shift_from "$target_date" 1 "%s") || return 1
    if ! [[ "$end_epoch" =~ ^-?[0-9]+$ ]]; then
        return 1
    fi
    if [ "$end_epoch" -le "$start_epoch" ]; then
        return 1
    fi

    local start_utc
    local end_utc
    start_utc=$(epoch_to_utc_iso "$start_epoch") || return 1
    end_utc=$(epoch_to_utc_iso "$end_epoch") || return 1

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
    # shellcheck disable=SC2064
    trap "rm -f '$tmp_response' '$primary_err' '$fallback_err' '$header_file'" RETURN

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
        return 0
    fi

    echo "Error: Failed to reach GitHub for $endpoint." >&2
    return 1
}

# --- Public Interface Functions ---

_filter_repo_json() {
    local json_data="$1"
    local filter="."

    if [ "${GITHUB_EXCLUDE_FORKS:-false}" = "true" ]; then
        filter+=" | map(select(.fork == false))"
    fi

    if [ "${GITHUB_EXCLUDE_REPOS:-}" ]; then
        printf "%s" "$json_data" | jq --arg exclude "$GITHUB_EXCLUDE_REPOS" \
            "(\$exclude | split(\",\") | map(gsub(\"^[[:space:]]+|[[:space:]]+$\";\"\"))) as \$ex_list | $filter | map(select(.name as \$n | \$ex_list | index(\$n) | not))"
    else
        printf "%s" "$json_data" | jq "$filter"
    fi
}

_allowed_repo_names() {
    local repo_endpoint="/users/$USERNAME/repos?sort=pushed&per_page=100"
    local cache_file=""
    local repo_json=""

    cache_file=$(_cache_path_for "$repo_endpoint")
    if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
        repo_json=$(cat "$cache_file" 2>/dev/null || true)
        if [ -n "$repo_json" ]; then
            _filter_repo_json "$repo_json" | jq -r '.[].name' 2>/dev/null || true
            return 0
        fi
    fi

    if repo_json=$(list_repos 2>/dev/null); then
        printf '%s' "$repo_json" | jq -r '.[].name' 2>/dev/null || true
        return 0
    fi

    echo "Warning: Unable to refresh filtered repository list; commit filtering may include forks." >&2
    return 1
}

# Lists all repositories for the configured user, sorted by most recently pushed.
# Fetches up to 100 repositories.
list_repos() {
    local json_data
    if ! json_data=$(_github_api_call "/users/$USERNAME/repos?sort=pushed&per_page=100"); then
        echo "Error: Failed to fetch repositories" >&2
        return 1
    fi

    _filter_repo_json "$json_data"
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
# Lists commits for a specific date (YYYY-MM-DD) natively via GraphQL.
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
    utc_start=$(echo "$window_data" | sed -n '1p')
    utc_end=$(echo "$window_data" | sed -n '2p')
    local cache_file
    cache_file=$(_commit_activity_cache_path_for_date "$target_date")

    # Optional exclude filtering
    local allowed_repos=""
    if [ "${GITHUB_EXCLUDE_FORKS:-false}" = "true" ] || [ -n "${GITHUB_EXCLUDE_REPOS:-}" ]; then
        allowed_repos=$(_allowed_repo_names || true)
    fi

    local query='query {
      user(login: "'"$USERNAME"'") {
        repositories(first: 30, orderBy: {field: PUSHED_AT, direction: DESC}) {
          nodes {
            name
            defaultBranchRef {
              target {
                ... on Commit {
                  history(since: "'"$utc_start"'", until: "'"$utc_end"'") {
                    nodes {
                      oid
                      messageHeadline
                    }
                  }
                }
              }
            }
          }
        }
      }
    }'

    local tmp_payload
    local tmp_response
    local curl_err
    local used_cache=false
    tmp_payload=$(mktemp -t "gh_gql_req.XXXXXX")
    tmp_response=$(mktemp -t "gh_gql_res.XXXXXX")
    curl_err=$(mktemp -t "gh_gql_err.XXXXXX")

    # shellcheck disable=SC2064
    trap "rm -f '$tmp_payload' '$tmp_response' '$curl_err'" RETURN

    # Build the JSON payload safely
    jq -n --arg q "$query" '{query: $q}' > "$tmp_payload"

    if ! curl -fsS -L \
         --connect-timeout "$GITHUB_CONNECT_TIMEOUT" \
         --max-time "$GITHUB_REQUEST_TIMEOUT" \
         -H "Authorization: bearer $TOKEN" \
         -H "Content-Type: application/json" \
         -X POST -d "@$tmp_payload" \
         "https://api.github.com/graphql" -o "$tmp_response" 2>"$curl_err"; then
        if [ "$GITHUB_DEBUG" = "true" ] && [ -s "$curl_err" ]; then
            _github_debug_log "Primary Err: $(head -n 1 "$curl_err" | tr -d '\r')"
        fi
        if ! _restore_commit_activity_cache "$cache_file" "$target_date" "$tmp_response"; then
            echo "Error: Failed to reach GitHub GraphQL API" >&2
            return 1
        fi
        used_cache=true
    fi

    if ! jq empty "$tmp_response" >/dev/null 2>&1; then
        if ! _restore_commit_activity_cache "$cache_file" "$target_date" "$tmp_response"; then
            echo "Error: Invalid response from GitHub GraphQL API" >&2
            return 1
        fi
        used_cache=true
    fi

    if jq -e '.errors? | type == "array" and length > 0' "$tmp_response" >/dev/null 2>&1; then
        if [ "$GITHUB_DEBUG" = "true" ]; then
            _github_debug_log "GraphQL Err: $(jq -r '.errors[0].message // "unknown GraphQL error"' "$tmp_response" 2>/dev/null)"
        fi
        if ! _restore_commit_activity_cache "$cache_file" "$target_date" "$tmp_response"; then
            echo "Error: GitHub GraphQL returned an error for commit activity" >&2
            return 1
        fi
        used_cache=true
    fi

    if [ "$used_cache" = false ] && [ -n "$cache_file" ]; then
        cp "$tmp_response" "$cache_file"
    fi

    local raw_commits
    raw_commits=$(jq -r '
        try (
            .data.user.repositories.nodes[] | 
            select(.defaultBranchRef != null) | 
            .name as $repo | 
            .defaultBranchRef.target.history.nodes[]? | 
            "\($repo)|\(.oid[0:7])|\(.messageHeadline | gsub("\\|"; "/"))"
        ) catch empty
    ' "$tmp_response" 2>/dev/null || true)

    if [ -z "$raw_commits" ]; then
        return 0
    fi

    local final_commits=""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local repo_name
        repo_name="${line%%|*}"
        
        # Apply repo exclusions if active
        if [ -n "$allowed_repos" ] && ! printf '%s\n' "$allowed_repos" | grep -Fxq "$repo_name"; then
            continue
        fi
        
        final_commits+="${line}"$'\n'
    done <<< "$raw_commits"

    if [ -n "$final_commits" ]; then
        printf "%s" "$final_commits" | awk 'NF' | sort -u
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
