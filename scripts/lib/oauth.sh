#!/usr/bin/env bash
# oauth.sh - Shared OAuth token helpers
# Dependencies (caller must source explicitly when needed):
# - date_utils.sh for date_epoch_now (falls back to `date +%s` when unavailable)
# - common.sh/file_ops.sh for atomic_write (falls back to plain writes when unavailable)
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_OAUTH_SH_LOADED:-}" ]]; then
    return 0
fi
readonly _OAUTH_SH_LOADED=true

oauth_extract_access_token() {
    local response_json="${1:-}"
    printf '%s' "$response_json" | jq -r '.access_token // empty' 2>/dev/null || true
}

oauth_extract_refresh_token() {
    local response_json="${1:-}"
    printf '%s' "$response_json" | jq -r '.refresh_token // empty' 2>/dev/null || true
}

oauth_extract_expires_in() {
    local response_json="${1:-}"
    local default_value="${2:-3600}"
    local expires_in

    expires_in=$(printf '%s' "$response_json" | jq -r --argjson default_value "$default_value" '.expires_in // $default_value' 2>/dev/null || printf '%s' "$default_value")
    [[ "$expires_in" =~ ^[0-9]+$ ]] || expires_in="$default_value"
    printf '%s' "$expires_in"
}

oauth_extract_error_code() {
    local response_json="${1:-}"
    printf '%s' "$response_json" | jq -r '.error // empty' 2>/dev/null || true
}

oauth_extract_error_description() {
    local response_json="${1:-}"
    printf '%s' "$response_json" | jq -r '.error_description // empty' 2>/dev/null || true
}

oauth_format_error_message() {
    local response_json="${1:-}"
    local error_prefix="${2:-OAuth request failed}"
    local fallback_message="${3:-OAuth response did not contain access_token}"
    local error_code
    local error_description

    error_code="$(oauth_extract_error_code "$response_json")"
    error_description="$(oauth_extract_error_description "$response_json")"

    if [[ -n "$error_code" && -n "$error_description" ]]; then
        printf '%s: %s (%s)' "$error_prefix" "$error_code" "$error_description"
        return 0
    fi
    if [[ -n "$error_code" ]]; then
        printf '%s: %s' "$error_prefix" "$error_code"
        return 0
    fi

    printf '%s' "$fallback_message"
}

oauth_compute_expiry_epoch() {
    local expires_in="${1:-3600}"
    local buffer_seconds="${2:-60}"
    local now_epoch
    local usable_window

    [[ "$expires_in" =~ ^[0-9]+$ ]] || expires_in=3600
    [[ "$buffer_seconds" =~ ^[0-9]+$ ]] || buffer_seconds=60

    if type date_epoch_now >/dev/null 2>&1; then
        now_epoch="$(date_epoch_now)"
    else
        now_epoch="$(date +%s)"
    fi

    usable_window=$((expires_in - buffer_seconds))
    if (( usable_window < 60 )); then
        usable_window=60
    fi

    printf '%s' "$((now_epoch + usable_window))"
}

oauth_write_refresh_credentials() {
    local creds_file="$1"
    local client_id="$2"
    local client_secret="$3"
    local refresh_token="$4"
    local content

    mkdir -p "$(dirname "$creds_file")"
    content=$(jq -n \
        --arg cid "$client_id" \
        --arg secret "$client_secret" \
        --arg refresh "$refresh_token" \
        '{client_id: $cid, client_secret: $secret, refresh_token: $refresh}')

    if type atomic_write >/dev/null 2>&1; then
        atomic_write "$content" "$creds_file" || return 1
    else
        printf '%s' "$content" > "$creds_file" || return 1
    fi
    chmod 600 "$creds_file" 2>/dev/null || true
}

oauth_write_access_token_cache() {
    local token_file="$1"
    local access_token="$2"
    local expires_in="${3:-3600}"
    local expiry_epoch
    local content

    expiry_epoch="$(oauth_compute_expiry_epoch "$expires_in")"
    mkdir -p "$(dirname "$token_file")"
    content=$(jq -n \
        --arg token "$access_token" \
        --argjson expiry "$expiry_epoch" \
        '{access_token: $token, expiry: $expiry}')

    if type atomic_write >/dev/null 2>&1; then
        atomic_write "$content" "$token_file" || return 1
    else
        printf '%s' "$content" > "$token_file" || return 1
    fi
    chmod 600 "$token_file" 2>/dev/null || true
}

oauth_refresh_token_request() {
    local token_url="$1"
    local client_id="$2"
    local client_secret="$3"
    local refresh_token="$4"
    local request_runner="${5:-curl}"

    "$request_runner" \
        -d "client_id=$client_id" \
        -d "client_secret=$client_secret" \
        -d "refresh_token=$refresh_token" \
        -d "grant_type=refresh_token" \
        "$token_url"
}
