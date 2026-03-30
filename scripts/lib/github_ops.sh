#!/usr/bin/env bash
# scripts/lib/github_ops.sh
# Shared GitHub activity operations
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_GITHUB_OPS_LOADED:-}" ]]; then
    return 0
fi
readonly _GITHUB_OPS_LOADED=true

_github_ops_debug() {
    if [ "${GITHUB_DEBUG:-false}" = "true" ]; then
        echo "$*" >&2
    fi
}

_log_github_helper_error() {
    local err_file="$1"
    local err_msg=""

    err_msg=$(_extract_github_error "$err_file")

    if [ "${GITHUB_DEBUG:-false}" = "true" ]; then
        # In debug mode, surface helper diagnostics so connectivity/auth issues
        # are visible without rerunning helper scripts manually.
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            echo "$line" >&2
        done < "$err_file"
        return 0
    fi

    if [ -n "$err_msg" ]; then
        _github_ops_debug "$err_msg"
    fi
}

_extract_github_error() {
    local err_file="$1"
    local line=""

    line=$(grep -E '^(Error|Warning):' "$err_file" | head -n 1 || true)
    if [ -z "$line" ]; then
        line=$(grep -Ev '^(Debug|Primary Err|Fallback Err|Scopes:|$)' "$err_file" | head -n 1 || true)
    fi

    printf "%s" "$line"
}

# Get recent GitHub activity as structured pipe-delimited data.
# Usage: get_recent_github_activity_structured [days]
# Output format: repo_name|days_ago|pushed_at_iso
# Returns one line per repo pushed within the window.
get_recent_github_activity_structured() {
    local days="${1:-7}"
    local _github_ops_lib_dir
    _github_ops_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local helper_script="${_github_ops_lib_dir}/../github_helper.sh"

    if [ ! -f "$helper_script" ]; then
        return 0
    fi

    if ! command -v jq >/dev/null 2>&1; then
        _github_ops_debug "jq not found; cannot parse GitHub activity."
        return 1
    fi
    if ! command -v timestamp_to_epoch >/dev/null 2>&1 || ! command -v date_epoch_now >/dev/null 2>&1; then
        _github_ops_debug "date_utils helpers are not loaded."
        return 1
    fi

    local github_repos err_file
    err_file=$(mktemp -t "github-helper.XXXXXX") && chmod 600 "$err_file"
    if ! github_repos=$("$helper_script" list_repos 2> "$err_file"); then
        [ -s "$err_file" ] && _log_github_helper_error "$err_file"
        rm -f "$err_file"
        return 1
    fi
    rm -f "$err_file"

    local repo_lines
    repo_lines=$(echo "$github_repos" | jq -r '.[] | "\(.pushed_at) \(.name)"')
    local now
    now=$(date_epoch_now)

    while read -r line; do
        [ -z "$line" ] && continue
        local pushed_at_str repo_name pushed_at_epoch diff_days
        pushed_at_str=$(echo "$line" | awk '{print $1}')
        repo_name=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
        pushed_at_epoch=$(timestamp_to_epoch "$pushed_at_str")
        [ "$pushed_at_epoch" -le 0 ] && continue
        diff_days=$(( (now - pushed_at_epoch) / 86400 ))
        if [ "$diff_days" -le "$days" ]; then
            printf '%s|%s|%s\n' "$repo_name" "$diff_days" "$pushed_at_str"
        else
            break
        fi
    done <<< "$repo_lines"
}

# Get recent GitHub activity (pushes in the last 7 days) — formatted for display.
# Usage: get_recent_github_activity [days]
# Wraps get_recent_github_activity_structured with human-readable formatting.
get_recent_github_activity() {
    local days="${1:-7}"
    local structured
    structured=$(get_recent_github_activity_structured "$days") || return $?

    [[ -z "$structured" ]] && return 0

    while IFS='|' read -r repo_name diff_days _pushed_at; do
        [[ -z "$repo_name" ]] && continue
        local day_text
        if [ "$diff_days" -eq 0 ]; then
            day_text="today"
        elif [ "$diff_days" -eq 1 ]; then
            day_text="yesterday"
        else
            day_text="$diff_days days ago"
        fi
        echo "  • $repo_name (pushed $day_text)"
    done <<< "$structured"
}

# Get commit activity for a specific date as structured pipe-delimited data.
# Usage: get_commit_activity_for_date_structured "2026-02-03"
# Output format: repo|sha|message (one line per commit)
get_commit_activity_for_date_structured() {
    local target_date="$1"
    local _github_ops_lib_dir
    _github_ops_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local helper_script="${_github_ops_lib_dir}/../github_helper.sh"

    if [ -z "$target_date" ]; then
        return 1
    fi

    if [ ! -f "$helper_script" ]; then
        _github_ops_debug "GitHub helper not found at $helper_script"
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        _github_ops_debug "jq not found; cannot parse GitHub activity."
        return 1
    fi

    local commits err_file
    err_file=$(mktemp -t "github-commits.XXXXXX") && chmod 600 "$err_file"
    if ! commits=$("$helper_script" list_commits_for_date "$target_date" 2> "$err_file"); then
        [ -s "$err_file" ] && _log_github_helper_error "$err_file"
        rm -f "$err_file"
        return 1
    fi
    rm -f "$err_file"

    if [[ -n "$commits" ]]; then
        printf '%s\n' "$commits"
    fi

    return 0
}

# Get commit activity for a specific date (YYYY-MM-DD) — formatted for display.
# Usage: get_commit_activity_for_date "2026-02-03"
get_commit_activity_for_date() {
    local target_date="$1"
    local commits
    commits=$(get_commit_activity_for_date_structured "$target_date") || return $?

    if [ -z "$commits" ]; then
        echo "  (No commits for $target_date)"
        return 0
    fi

    while IFS='|' read -r repo sha message; do
        [ -z "$repo" ] && continue
        echo "  • $repo: $message ($sha)"
    done <<< "$commits"
}
