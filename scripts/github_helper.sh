#!/bin/bash
# github_helper.sh - Functions for interacting with the GitHub API

# --- Configuration ---
TOKEN_FILE="$HOME/.github_token"
USERNAME="ryan258" # Hardcoded as requested

# --- Check for dependencies ---
if ! command -v curl &> /dev/null;
then
    echo "Error: curl is not installed. Please install it." >&2
    exit 1
fi
if ! command -v jq &> /dev/null;
then
    echo "Error: jq is not installed. Please install it with 'brew install jq'." >&2
    exit 1
fi
if [ ! -f "$TOKEN_FILE" ];
then
    echo "Error: GitHub token not found at $TOKEN_FILE" >&2
    echo "Please create a token and save it to that file." >&2
    exit 1
fi
TOKEN=$(cat "$TOKEN_FILE")

# --- Private Helper Function for API calls ---
function _github_api_call() {
    local endpoint="$1"
    local api_url="https://api.github.com$endpoint"
    
    curl -s -H "Authorization: token $TOKEN" \
         -H "Accept: application/vnd.github.v3+json" \
         "$api_url"
}

# --- Public Functions ---

# List all repositories for the user
# Usage: list_repos
function list_repos() {
    # Fetches all repos, sorted by last push, 100 per page
    _github_api_call "/users/$USERNAME/repos?sort=pushed&per_page=100"
}

# Get details for a specific repository
# Usage: get_repo "repo_name"
function get_repo() {
    local repo_name="$1"
    _github_api_call "/repos/$USERNAME/$repo_name"
}

# Get the latest commit for a specific repository
# Usage: get_latest_commit "repo_name"
function get_latest_commit() {
    local repo_name="$1"
    # Get the first commit from the list
    _github_api_call "/repos/$USERNAME/$repo_name/commits?per_page=1" | jq '.[0]'
}

# Get the content of the README for a specific repository
# Usage: get_readme_content "repo_name"
function get_readme_content() {
    local repo_name="$1"
    # The 'content' field is Base64 encoded
    _github_api_call "/repos/$USERNAME/$repo_name/readme" | jq -r '.content' | base64 --decode
}


# --- Main Logic (Router) ---
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
