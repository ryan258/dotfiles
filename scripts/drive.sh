#!/usr/bin/env bash
set -euo pipefail

# drive.sh - Read-only Google Drive activity and recall helper

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_lib "config.sh"
require_lib "date_utils.sh"
require_lib "focus_relevance.sh"

CREDS_FILE="${GDRIVE_CREDS_FILE:?GDRIVE_CREDS_FILE is not set by config.sh}"
TOKEN_FILE="${GDRIVE_TOKEN_FILE:?GDRIVE_TOKEN_FILE is not set by config.sh}"
CACHE_FILE="${GDRIVE_CACHE_FILE:?GDRIVE_CACHE_FILE is not set by config.sh}"

AUTH_BASE="https://oauth2.googleapis.com"
API_BASE="https://www.googleapis.com/drive/v3"
SCOPE="https://www.googleapis.com/auth/drive.readonly"
GOOGLE_DRIVE_CLIENT_ID="${GOOGLE_DRIVE_CLIENT_ID:-}"
GOOGLE_DRIVE_CLIENT_SECRET="${GOOGLE_DRIVE_CLIENT_SECRET:-}"
GOOGLE_DRIVE_DEFAULT_DAYS="${GOOGLE_DRIVE_DEFAULT_DAYS:-7}"
DRIVE_CACHE_TTL_SECONDS="${DRIVE_CACHE_TTL_SECONDS:-900}"
GDRIVE_CONNECT_TIMEOUT_SECONDS="${GDRIVE_CONNECT_TIMEOUT_SECONDS:-5}"
GDRIVE_MAX_TIME_SECONDS="${GDRIVE_MAX_TIME_SECONDS:-20}"

mkdir -p "$DATA_DIR" "$CACHE_DIR"

[[ "$GDRIVE_CONNECT_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || GDRIVE_CONNECT_TIMEOUT_SECONDS=5
[[ "$GDRIVE_MAX_TIME_SECONDS" =~ ^[0-9]+$ ]] || GDRIVE_MAX_TIME_SECONDS=20

show_help() {
    cat <<EOF
Usage: $(basename "$0") {auth|status|recent|recall}

Commands:
  auth                       Authenticate with Google Drive (device flow)
  status                     Show local Drive auth/cache status
  recent [days]              Show recent relevant Docs activity (default: $GOOGLE_DRIVE_DEFAULT_DAYS)
  recall [query...]          Search for older relevant docs (uses current focus when omitted)
EOF
}

check_deps() {
    require_cmd "curl" "Install with: brew install curl"
    require_cmd "jq" "Install with: brew install jq"
}

json_file_valid() {
    local path="$1"
    [[ -f "$path" ]] || return 1
    jq empty "$path" >/dev/null 2>&1
}

_drive_curl() {
    curl -sS \
        --connect-timeout "$GDRIVE_CONNECT_TIMEOUT_SECONDS" \
        --max-time "$GDRIVE_MAX_TIME_SECONDS" \
        "$@"
}

load_creds() {
    if ! json_file_valid "$CREDS_FILE"; then
        die "Drive credentials not found. Run $(basename "$0") auth" "$EXIT_FILE_NOT_FOUND"
    fi
    GOOGLE_DRIVE_CLIENT_ID="$(jq -r '.client_id // empty' "$CREDS_FILE")"
    GOOGLE_DRIVE_CLIENT_SECRET="$(jq -r '.client_secret // empty' "$CREDS_FILE")"
    REFRESH_TOKEN="$(jq -r '.refresh_token // empty' "$CREDS_FILE")"
}

drive_cache_get() {
    local key="$1"
    local ttl="${2:-$DRIVE_CACHE_TTL_SECONDS}"
    local now_epoch
    now_epoch=$(date_epoch_now)

    if ! json_file_valid "$CACHE_FILE"; then
        return 1
    fi

    jq -e --arg key "$key" --argjson now "$now_epoch" --argjson ttl "$ttl" '
        .[$key] as $entry
        | select($entry != null)
        | select(($entry.fetched_at_epoch + $ttl) >= $now)
        | $entry.payload
    ' "$CACHE_FILE" 2>/dev/null || return 1
}

drive_cache_put() {
    local key="$1"
    local payload="$2"
    local temp_file
    local now_epoch

    temp_file=$(mktemp "${CACHE_FILE}.XXXXXX") || return 1
    now_epoch=$(date_epoch_now)

    if json_file_valid "$CACHE_FILE"; then
        jq --arg key "$key" --argjson epoch "$now_epoch" --argjson payload "$payload" \
            '.[$key] = {fetched_at_epoch: $epoch, payload: $payload}' \
            "$CACHE_FILE" > "$temp_file" || {
                rm -f "$temp_file"
                return 1
            }
    else
        jq -n --arg key "$key" --argjson epoch "$now_epoch" --argjson payload "$payload" \
            '{($key): {fetched_at_epoch: $epoch, payload: $payload}}' > "$temp_file" || {
                rm -f "$temp_file"
                return 1
            }
    fi

    mv "$temp_file" "$CACHE_FILE" || {
        rm -f "$temp_file"
        return 1
    }
}

drive_token_valid() {
    if ! json_file_valid "$TOKEN_FILE"; then
        return 1
    fi

    local expiry now_epoch
    expiry="$(jq -r '.expiry // 0' "$TOKEN_FILE")"
    now_epoch=$(date_epoch_now)
    [[ "$expiry" =~ ^[0-9]+$ ]] || return 1
    [[ "$now_epoch" -lt "$expiry" ]]
}

cmd_auth() {
    check_deps

    echo "=== Google Drive Authentication (Device Flow) ==="
    echo "Create OAuth credentials for 'TV and Limited Input devices'."
    echo ""

    if [[ -z "$GOOGLE_DRIVE_CLIENT_ID" ]]; then
        read -rp "Enter Client ID: " GOOGLE_DRIVE_CLIENT_ID
    fi
    if [[ -z "$GOOGLE_DRIVE_CLIENT_SECRET" ]]; then
        read -rp "Enter Client Secret: " GOOGLE_DRIVE_CLIENT_SECRET
    fi

    GOOGLE_DRIVE_CLIENT_ID=$(sanitize_single_line "$GOOGLE_DRIVE_CLIENT_ID")
    GOOGLE_DRIVE_CLIENT_SECRET=$(sanitize_single_line "$GOOGLE_DRIVE_CLIENT_SECRET")

    [[ -n "$GOOGLE_DRIVE_CLIENT_ID" ]] || die "Client ID is required" "$EXIT_INVALID_ARGS"
    [[ -n "$GOOGLE_DRIVE_CLIENT_SECRET" ]] || die "Client secret is required" "$EXIT_INVALID_ARGS"

    local response device_code user_code verification_url interval
    response=$(_drive_curl -d "client_id=$GOOGLE_DRIVE_CLIENT_ID" \
        -d "scope=$SCOPE" \
        "$AUTH_BASE/device/code")

    device_code=$(printf '%s' "$response" | jq -r '.device_code // empty')
    user_code=$(printf '%s' "$response" | jq -r '.user_code // empty')
    verification_url=$(printf '%s' "$response" | jq -r '.verification_url // empty')
    interval=$(printf '%s' "$response" | jq -r '.interval // 5')

    [[ -n "$device_code" ]] || die "Drive device-code request failed: $response" "$EXIT_SERVICE_ERROR"

    echo ""
    echo "1. Go to: $verification_url"
    echo "2. Enter code: $user_code"
    echo ""
    echo "Waiting for authorization..."

    while true; do
        sleep "${interval:-5}"
        local token_res error refresh_token access_token expires_in expiry
        token_res=$(_drive_curl -d "client_id=$GOOGLE_DRIVE_CLIENT_ID" \
            -d "client_secret=$GOOGLE_DRIVE_CLIENT_SECRET" \
            -d "device_code=$device_code" \
            -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
            "$AUTH_BASE/token")

        error=$(printf '%s' "$token_res" | jq -r '.error // empty')
        if [[ -z "$error" ]]; then
            refresh_token=$(printf '%s' "$token_res" | jq -r '.refresh_token // empty')
            access_token=$(printf '%s' "$token_res" | jq -r '.access_token // empty')
            expires_in=$(printf '%s' "$token_res" | jq -r '.expires_in // 3600')
            [[ -n "$access_token" && -n "$refresh_token" ]] || die "Drive auth did not return usable tokens" "$EXIT_SERVICE_ERROR"

            jq -n --arg cid "$GOOGLE_DRIVE_CLIENT_ID" --arg secret "$GOOGLE_DRIVE_CLIENT_SECRET" --arg refresh "$refresh_token" \
                '{client_id: $cid, client_secret: $secret, refresh_token: $refresh}' > "$CREDS_FILE"

            expiry=$(( $(date_epoch_now) + expires_in - 60 ))
            jq -n --arg token "$access_token" --argjson expiry "$expiry" \
                '{access_token: $token, expiry: $expiry}' > "$TOKEN_FILE"

            echo "✅ Drive authentication saved."
            return 0
        fi

        if [[ "$error" == "authorization_pending" ]]; then
            echo -n "."
        elif [[ "$error" == "slow_down" ]]; then
            interval=$((interval + 5))
            echo -n "."
        else
            echo ""
            die "Drive auth failed: $error" "$EXIT_SERVICE_ERROR"
        fi
    done
}

refresh_access_token() {
    check_deps
    load_creds

    [[ -n "${REFRESH_TOKEN:-}" ]] || die "Drive refresh token missing. Run $(basename "$0") auth" "$EXIT_ERROR"

    local refresh_res access_token expires_in expiry
    refresh_res=$(_drive_curl -d "client_id=$GOOGLE_DRIVE_CLIENT_ID" \
        -d "client_secret=$GOOGLE_DRIVE_CLIENT_SECRET" \
        -d "refresh_token=$REFRESH_TOKEN" \
        -d "grant_type=refresh_token" \
        "$AUTH_BASE/token")

    access_token=$(printf '%s' "$refresh_res" | jq -r '.access_token // empty')
    expires_in=$(printf '%s' "$refresh_res" | jq -r '.expires_in // 3600')
    [[ -n "$access_token" ]] || die "Drive token refresh failed: $refresh_res" "$EXIT_SERVICE_ERROR"

    expiry=$(( $(date_epoch_now) + expires_in - 60 ))
    jq -n --arg token "$access_token" --argjson expiry "$expiry" \
        '{access_token: $token, expiry: $expiry}' > "$TOKEN_FILE"

    printf '%s' "$access_token"
}

get_access_token() {
    if drive_token_valid; then
        jq -r '.access_token' "$TOKEN_FILE"
        return 0
    fi
    refresh_access_token
}

_drive_build_fields() {
    printf '%s' "files(id,name,mimeType,modifiedTime,viewedByMeTime,webViewLink)"
}

_drive_mime_filter() {
    printf '%s' "(mimeType = 'application/vnd.google-apps.document' or mimeType = 'application/vnd.google-apps.spreadsheet' or mimeType = 'application/vnd.google-apps.presentation')"
}

_drive_keyword_clause() {
    local keywords="$1"
    local clause=""
    local keyword=""

    # Callers must pass normalized alphanumeric keywords (for example from
    # focus_relevance_keywords_from_text), not raw user text.
    while IFS= read -r keyword; do
        [[ -z "$keyword" ]] && continue
        [[ "$keyword" =~ ^[[:alnum:]]+$ ]] || continue
        clause="${clause}${clause:+ or }name contains '$keyword' or fullText contains '$keyword'"
    done <<< "$keywords"

    if [[ -n "$clause" ]]; then
        printf '(%s)' "$clause"
    fi
}

_drive_rank_results() {
    local payload="$1"
    local keywords="$2"

    local keywords_json
    keywords_json=$(printf '%s\n' "$keywords" | sed '/^[[:space:]]*$/d' | jq -R . | jq -s .)

    printf '%s' "$payload" | jq --argjson keywords "$keywords_json" '
        def name_score($name):
            if ($keywords | length) == 0 then 0
            else ([ $keywords[] as $key | select(($name | ascii_downcase | contains($key))) ] | length)
            end;

        (.files // [])
        | map(
            .score = name_score(.name // "")
            | .recency_epoch = ((.viewedByMeTime // .modifiedTime // "1970-01-01T00:00:00Z") | fromdateiso8601? // 0)
          )
        | if ($keywords | length) > 0 then map(select(.score > 0)) else . end
        | sort_by(-.score, -.recency_epoch)
        | map(del(.recency_epoch))
    '
}

_drive_api_list_files() {
    local query="$1"
    local token response
    token=$(get_access_token)
    response=$(_drive_curl --get \
        -H "Authorization: Bearer $token" \
        --data-urlencode "q=$query" \
        --data-urlencode "pageSize=25" \
        --data-urlencode "orderBy=viewedByMeTime desc,modifiedTime desc" \
        --data-urlencode "fields=$(_drive_build_fields)" \
        "$API_BASE/files")

    if printf '%s' "$response" | jq -e '.error' >/dev/null 2>&1; then
        return 1
    fi

    printf '%s' "$response"
}

_drive_recent_query() {
    local days="$1"
    local keywords="$2"
    local start_date
    local cutoff_iso
    local query

    start_date=$(date_shift_days "-$((days-1))" "%Y-%m-%d")
    cutoff_iso="${start_date}T00:00:00Z"
    query="trashed = false and $(_drive_mime_filter()) and (modifiedTime >= '$cutoff_iso' or viewedByMeTime >= '$cutoff_iso')"

    local keyword_clause
    keyword_clause=$(_drive_keyword_clause "$keywords")
    if [[ -n "$keyword_clause" ]]; then
        query="$query and $keyword_clause"
    fi

    printf '%s' "$query"
}

_drive_recall_query() {
    local keywords="$1"
    local keyword_clause
    keyword_clause=$(_drive_keyword_clause "$keywords")
    if [[ -z "$keyword_clause" ]]; then
        return 1
    fi

    printf "trashed = false and %s and %s" "$(_drive_mime_filter())" "$keyword_clause"
}

_drive_human_label() {
    local mime="$1"
    case "$mime" in
        application/vnd.google-apps.document) printf '%s' "Doc" ;;
        application/vnd.google-apps.spreadsheet) printf '%s' "Sheet" ;;
        application/vnd.google-apps.presentation) printf '%s' "Slide" ;;
        *) printf '%s' "File" ;;
    esac
}

_drive_base64_decode() {
    if [[ "$OSTYPE" == darwin* ]]; then
        base64 -D
        return
    fi

    if base64 --help 2>/dev/null | grep -q -- '--decode'; then
        base64 --decode
    else
        base64 -d
    fi
}

_drive_print_results() {
    local results="$1"
    local heading="$2"

    if [[ "$(printf '%s' "$results" | jq 'length')" -eq 0 ]]; then
        echo "No Drive files found."
        return 0
    fi

    echo "$heading"
    printf '%s' "$results" | jq -r '.[] | @base64' | awk '{ print NR "|" $0 }' | while IFS='|' read -r index row; do
        local decoded name mime modified viewed score link
        decoded=$(printf '%s' "$row" | _drive_base64_decode 2>/dev/null)
        name=$(printf '%s' "$decoded" | jq -r '.name')
        mime=$(printf '%s' "$decoded" | jq -r '.mimeType')
        modified=$(printf '%s' "$decoded" | jq -r '.modifiedTime // "n/a"')
        viewed=$(printf '%s' "$decoded" | jq -r '.viewedByMeTime // "n/a"')
        score=$(printf '%s' "$decoded" | jq -r '.score // 0')
        link=$(printf '%s' "$decoded" | jq -r '.webViewLink // ""')
        printf '%s. [%s] %s (score %s)\n' "$index" "$(_drive_human_label "$mime")" "$name" "$score"
        printf '   viewed: %s | modified: %s\n' "$viewed" "$modified"
        if [[ -n "$link" && "$link" != "null" ]]; then
            printf '   %s\n' "$link"
        fi
    done
}

cmd_status() {
    echo "=== Google Drive Status ==="
    if json_file_valid "$CREDS_FILE"; then
        echo "Auth: configured"
    else
        echo "Auth: missing (run $(basename "$0") auth)"
    fi

    if drive_token_valid; then
        echo "Token: valid"
    elif json_file_valid "$TOKEN_FILE"; then
        echo "Token: expired or refresh needed"
    else
        echo "Token: missing"
    fi

    if json_file_valid "$CACHE_FILE"; then
        echo "Cache: available at $CACHE_FILE"
    else
        echo "Cache: empty"
    fi
}

cmd_recent() {
    local days="$GOOGLE_DRIVE_DEFAULT_DAYS"
    local json_output="false"
    local quiet="false"
    local focus_text=""
    local keywords=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) json_output="true" ;;
            --quiet) quiet="true" ;;
            *)
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    days="$1"
                fi
                ;;
        esac
        shift
    done

    focus_text=$(focus_relevance_current_focus 2>/dev/null || true)
    if [[ -n "$focus_text" ]]; then
        keywords=$(focus_relevance_keywords_from_text "$focus_text")
    fi

    local cache_key query response results
    cache_key="recent:${days}:$(printf '%s' "$keywords" | tr '\n' ',' | tr -d ' ')"
    if response=$(drive_cache_get "$cache_key" "$DRIVE_CACHE_TTL_SECONDS" 2>/dev/null); then
        :
    else
        query=$(_drive_recent_query "$days" "$keywords")
        if ! response=$(_drive_api_list_files "$query" 2>/dev/null); then
            if [[ "$json_output" == "true" ]]; then
                printf '[]\n'
                return 0
            fi
            if [[ "$quiet" != "true" ]]; then
                echo "Unable to fetch recent Drive activity right now."
            fi
            return 0
        fi
        drive_cache_put "$cache_key" "$response" >/dev/null 2>&1 || true
    fi

    results=$(_drive_rank_results "$response" "$keywords")
    if [[ "$json_output" == "true" ]]; then
        printf '%s\n' "$results"
        return 0
    fi
    _drive_print_results "$results" "=== Recent Drive Activity (${days}d) ==="
}

cmd_recall() {
    local json_output="false"
    local quiet="false"
    local query_text=""
    local keywords=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) json_output="true"; shift ;;
            --quiet) quiet="true"; shift ;;
            *) break ;;
        esac
    done

    query_text="$*"
    if [[ -z "$query_text" ]]; then
        query_text=$(focus_relevance_current_focus 2>/dev/null || true)
    fi

    if [[ -z "$query_text" ]]; then
        if [[ "$json_output" == "true" ]]; then
            printf '[]\n'
            return 0
        fi
        echo "No query provided and no current focus set. Use: /f set <focus> or drive.sh recall <query>"
        return "$EXIT_INVALID_ARGS"
    fi

    keywords=$(focus_relevance_keywords_from_text "$query_text")
    if [[ -z "$keywords" ]]; then
        if [[ "$json_output" == "true" ]]; then
            printf '[]\n'
            return 0
        fi
        echo "No usable recall keywords found. Try a more specific query."
        return "$EXIT_INVALID_ARGS"
    fi

    local query response results
    query=$(_drive_recall_query "$keywords") || {
        if [[ "$json_output" == "true" ]]; then
            printf '[]\n'
            return 0
        fi
        echo "No usable recall keywords found. Try a more specific query."
        return "$EXIT_INVALID_ARGS"
    }

    if ! response=$(_drive_api_list_files "$query" 2>/dev/null); then
        if [[ "$json_output" == "true" ]]; then
            printf '[]\n'
            return 0
        fi
        if [[ "$quiet" != "true" ]]; then
            echo "Unable to search Drive right now."
        fi
        return 0
    fi

    results=$(_drive_rank_results "$response" "$keywords")
    results=$(printf '%s' "$results" | jq '.[0:5]')
    if [[ "$json_output" == "true" ]]; then
        printf '%s\n' "$results"
        return 0
    fi
    _drive_print_results "$results" "=== Drive Recall Results ==="
}

main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        auth) cmd_auth "$@" ;;
        status) cmd_status "$@" ;;
        recent) cmd_recent "$@" ;;
        recall) cmd_recall "$@" ;;
        help|-h|--help) show_help ;;
        *)
            echo "Unknown drive command: $cmd" >&2
            show_help
            exit "$EXIT_INVALID_ARGS"
            ;;
    esac
}

main "$@"
