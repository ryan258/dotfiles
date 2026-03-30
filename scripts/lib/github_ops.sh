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

_github_inactive_repos_file() {
    if [[ -n "${GITHUB_INACTIVE_REPOS_FILE:-}" ]]; then
        printf '%s' "$GITHUB_INACTIVE_REPOS_FILE"
        return 0
    fi

    printf '%s' "${DATA_DIR:-${XDG_DATA_HOME:-$HOME/.config}/dotfiles-data}/github_inactive_repos.txt"
}

_github_normalize_repo_name() {
    local repo_name="${1:-}"
    repo_name=$(printf '%s' "$repo_name" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    printf '%s' "$repo_name"
}

_github_repo_name_is_valid() {
    local repo_name="$(_github_normalize_repo_name "${1:-}")"
    [[ "$repo_name" =~ ^[A-Za-z0-9._-]+$ ]]
}

_github_repo_today() {
    if command -v date_today >/dev/null 2>&1; then
        date_today
        return 0
    fi

    date +"%Y-%m-%d"
}

list_inactive_github_repos_structured() {
    local inactive_file
    inactive_file=$(_github_inactive_repos_file)

    [[ -f "$inactive_file" ]] || return 0

    awk -F'|' '
        NF >= 1 && $1 != "" {
            repo=$1
            date=(NF >= 2 ? $2 : "")
            note=(NF >= 3 ? $3 : "")
            latest[repo]=repo "|" date "|" note
        }
        END {
            for (repo in latest) {
                print latest[repo]
            }
        }
    ' "$inactive_file" | LC_ALL=C sort
}

get_inactive_github_repo_names() {
    local structured=""

    structured=$(list_inactive_github_repos_structured)
    [[ -n "$structured" ]] || return 0

    while IFS='|' read -r repo_name _inactive_date _inactive_note; do
        [[ -n "$repo_name" ]] || continue
        printf '%s\n' "$repo_name"
    done <<< "$structured"
}

get_inactive_github_repos() {
    local structured=""

    structured=$(list_inactive_github_repos_structured)
    [[ -n "$structured" ]] || return 0

    while IFS='|' read -r repo_name inactive_date inactive_note; do
        [[ -n "$repo_name" ]] || continue
        if [[ -n "$inactive_note" ]]; then
            printf '  • %s (inactive %s - %s)\n' "$repo_name" "${inactive_date:-unknown}" "$inactive_note"
        elif [[ -n "$inactive_date" ]]; then
            printf '  • %s (inactive %s)\n' "$repo_name" "$inactive_date"
        else
            printf '  • %s\n' "$repo_name"
        fi
    done <<< "$structured"
}

_github_filter_inactive_repo_lines() {
    local input_lines="${1:-}"
    local repo_field="${2:-1}"
    local inactive_file=""

    [[ -n "$input_lines" ]] || return 0

    inactive_file=$(_github_inactive_repos_file)
    if [[ ! -f "$inactive_file" ]]; then
        printf '%s\n' "$input_lines"
        return 0
    fi

    printf '%s\n' "$input_lines" | awk -F'|' -v repo_field="$repo_field" '
        NR == FNR {
            if ($1 != "") {
                inactive[$1]=1
            }
            next
        }
        {
            repo=$repo_field
            if (!(repo in inactive)) {
                print
            }
        }
    ' "$inactive_file" -
}

is_github_repo_inactive() {
    local repo_name=""
    local inactive_file=""

    repo_name=$(_github_normalize_repo_name "${1:-}")
    [[ -n "$repo_name" ]] || return 1

    inactive_file=$(_github_inactive_repos_file)
    [[ -f "$inactive_file" ]] || return 1

    awk -F'|' -v repo="$repo_name" '
        $1 == repo {
            found=1
            exit
        }
        END {
            exit(found ? 0 : 1)
        }
    ' "$inactive_file"
}

deactivate_github_repo() {
    local repo_name=""
    local inactive_note="${*:2}"
    local inactive_file=""
    local tmp_file=""
    local inactive_date=""

    repo_name=$(_github_normalize_repo_name "${1:-}")
    if ! _github_repo_name_is_valid "$repo_name"; then
        echo "Invalid repo name: ${1:-}" >&2
        return 1
    fi

    inactive_file=$(_github_inactive_repos_file)
    mkdir -p "$(dirname "$inactive_file")"
    tmp_file=$(mktemp -t "github-inactive-repos.XXXXXX") || return 1
    chmod 600 "$tmp_file"

    if [[ -f "$inactive_file" ]]; then
        awk -F'|' -v repo="$repo_name" '$1 != repo' "$inactive_file" > "$tmp_file"
    fi

    inactive_date=$(_github_repo_today)
    printf '%s|%s|%s\n' "$repo_name" "$inactive_date" "$inactive_note" >> "$tmp_file"
    mv "$tmp_file" "$inactive_file"
    chmod 600 "$inactive_file" 2>/dev/null || true
}

reactivate_github_repo() {
    local repo_name=""
    local inactive_file=""
    local tmp_file=""

    repo_name=$(_github_normalize_repo_name "${1:-}")
    if ! _github_repo_name_is_valid "$repo_name"; then
        echo "Invalid repo name: ${1:-}" >&2
        return 1
    fi

    inactive_file=$(_github_inactive_repos_file)
    [[ -f "$inactive_file" ]] || return 0

    tmp_file=$(mktemp -t "github-inactive-repos.XXXXXX") || return 1
    chmod 600 "$tmp_file"
    awk -F'|' -v repo="$repo_name" '$1 != repo' "$inactive_file" > "$tmp_file"

    if [[ -s "$tmp_file" ]]; then
        mv "$tmp_file" "$inactive_file"
        chmod 600 "$inactive_file" 2>/dev/null || true
    else
        rm -f "$tmp_file" "$inactive_file"
    fi
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
    local structured_lines=""
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
            structured_lines="${structured_lines}${structured_lines:+$'\n'}${repo_name}|${diff_days}|${pushed_at_str}"
        else
            break
        fi
    done <<< "$repo_lines"

    if [[ -n "$structured_lines" ]]; then
        _github_filter_inactive_repo_lines "$structured_lines" 1
    fi
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
        _github_filter_inactive_repo_lines "$commits" 1
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
