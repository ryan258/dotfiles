#!/usr/bin/env bash
set -euo pipefail

# fitbit_sync.sh - OAuth setup and Fitbit API sync into local metric files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_lib "config.sh"
require_lib "date_utils.sh"

require_cmd "curl" "Install curl"
require_cmd "python3" "Install Python 3"

ensure_data_dirs

FITBIT_AUTH_FILE="${FITBIT_AUTH_FILE:-$DATA_DIR/fitbit_oauth.json}"
FITBIT_PENDING_FILE="${FITBIT_PENDING_FILE:-$DATA_DIR/fitbit_oauth_pending.json}"
FITBIT_SYNC_STATE_FILE="${FITBIT_SYNC_STATE_FILE:-$DATA_DIR/fitbit_sync_state.json}"
FITBIT_DATA_DIR="${FITBIT_DATA_DIR:-$DATA_DIR/fitbit}"
FITBIT_CLIENT_ID="${FITBIT_CLIENT_ID:-}"
FITBIT_CLIENT_SECRET="${FITBIT_CLIENT_SECRET:-}"
FITBIT_REDIRECT_URI="${FITBIT_REDIRECT_URI:-http://127.0.0.1:8765/callback}"
FITBIT_SCOPES="${FITBIT_SCOPES:-activity heartrate sleep profile}"
FITBIT_DEFAULT_DAYS="${FITBIT_DEFAULT_DAYS:-7}"

readonly FITBIT_AUTHORIZE_URL="https://www.fitbit.com/oauth2/authorize"
readonly FITBIT_TOKEN_URL="https://api.fitbit.com/oauth2/token"
readonly FITBIT_API_BASE="https://api.fitbit.com"

mkdir -p "$FITBIT_DATA_DIR"
chmod 700 "$FITBIT_DATA_DIR" 2>/dev/null || true

show_help() {
    cat <<EOF
Usage: $(basename "$0") {auth|auth-url|auth-exchange|sync|status|latest|help}

Commands:
  auth
      Interactive helper. Builds an authorization URL, then exchanges the
      returned code for Fitbit API tokens.

  auth-url
      Print an OAuth authorization URL and save the pending PKCE state locally.

  auth-exchange <redirect_url_or_code>
      Exchange an OAuth redirect URL or raw authorization code for tokens.

  sync [days]
      Pull Fitbit data for the last N days (default: $FITBIT_DEFAULT_DAYS) and
      write normalized daily metrics under ~/.config/dotfiles-data/fitbit/.

  status
      Show Fitbit auth and sync status.

  latest
      Show the newest local Fitbit metric values.

Environment:
  FITBIT_CLIENT_ID
  FITBIT_CLIENT_SECRET
  FITBIT_REDIRECT_URI
  FITBIT_SCOPES
  FITBIT_DEFAULT_DAYS

Notes:
  - Fitbit developer apps must register the redirect URI before auth succeeds.
  - The Fitbit Web API is slated for deprecation in September 2026, so this
    script keeps all downstream files normalized and local-first.
EOF
}

set_private_permissions() {
    local target="$1"
    chmod 600 "$target" 2>/dev/null || true
}

json_get() {
    local file_path="$1"
    local key="$2"

    python3 - "$file_path" "$key" <<'PY'
import json
import os
import sys

path, key = sys.argv[1:3]
if not os.path.exists(path):
    raise SystemExit(0)

with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

value = data.get(key, "")
if value is None:
    print("")
elif isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
}

write_json_file() {
    local target_file="$1"
    local content="$2"

    atomic_write "$content" "$target_file" || die "Failed to write $target_file" "$EXIT_ERROR"
    set_private_permissions "$target_file"
}

save_pending_auth() {
    local client_id="$1"
    local client_secret="$2"
    local redirect_uri="$3"
    local scopes="$4"

    local pending_json
    pending_json="$(python3 - "$client_id" "$client_secret" "$redirect_uri" "$scopes" <<'PY'
import base64
import hashlib
import json
import secrets
import sys

client_id, client_secret, redirect_uri, scopes = sys.argv[1:5]
verifier = secrets.token_urlsafe(64)
challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode("utf-8")).digest()).decode("ascii").rstrip("=")
state = secrets.token_urlsafe(24)

print(json.dumps({
    "client_id": client_id,
    "client_secret": client_secret,
    "redirect_uri": redirect_uri,
    "scopes": scopes,
    "code_verifier": verifier,
    "code_challenge": challenge,
    "state": state,
}, indent=2, sort_keys=True))
PY
)"

    write_json_file "$FITBIT_PENDING_FILE" "$pending_json"
}

build_auth_url() {
    local client_id="$1"
    local redirect_uri="$2"
    local scopes="$3"
    local code_challenge="$4"
    local state="$5"

    python3 - "$client_id" "$redirect_uri" "$scopes" "$code_challenge" "$state" "$FITBIT_AUTHORIZE_URL" <<'PY'
import sys
from urllib.parse import urlencode

client_id, redirect_uri, scopes, code_challenge, state, base_url = sys.argv[1:7]
params = urlencode({
    "response_type": "code",
    "client_id": client_id,
    "redirect_uri": redirect_uri,
    "scope": scopes,
    "code_challenge": code_challenge,
    "code_challenge_method": "S256",
    "state": state,
})
print(f"{base_url}?{params}")
PY
}

prompt_if_missing() {
    local current_value="$1"
    local prompt_text="$2"
    local secret_mode="${3:-false}"

    if [[ -n "$current_value" ]]; then
        printf '%s' "$current_value"
        return 0
    fi

    local answer=""
    if [[ "$secret_mode" == "true" ]]; then
        read -rsp "$prompt_text" answer
        printf '\n'
    else
        read -rp "$prompt_text" answer
    fi
    answer=$(sanitize_single_line "$answer")
    printf '%s' "$answer"
}

resolve_client_id() {
    local value="${FITBIT_CLIENT_ID:-}"
    if [[ -z "$value" ]]; then
        value="$(json_get "$FITBIT_AUTH_FILE" "client_id")"
    fi
    value=$(prompt_if_missing "$value" "Enter Fitbit Client ID: ")
    [[ -n "$value" ]] || die "Fitbit Client ID is required" "$EXIT_INVALID_ARGS"
    printf '%s' "$value"
}

resolve_client_secret() {
    local value="${FITBIT_CLIENT_SECRET:-}"
    if [[ -z "$value" ]]; then
        value="$(json_get "$FITBIT_AUTH_FILE" "client_secret")"
    fi
    if [[ -z "$value" ]]; then
        value=$(prompt_if_missing "" "Enter Fitbit Client Secret (optional, press Enter to skip): " true)
    fi
    printf '%s' "$value"
}

base64_basic_auth() {
    local client_id="$1"
    local client_secret="$2"

    python3 - "$client_id" "$client_secret" <<'PY'
import base64
import sys

client_id, client_secret = sys.argv[1:3]
raw = f"{client_id}:{client_secret}".encode("utf-8")
print(base64.b64encode(raw).decode("ascii"))
PY
}

token_request() {
    local grant_type="$1"
    local client_id="$2"
    local client_secret="$3"
    shift 3 || true

    local curl_args=(
        -sS
        -X POST
        -H "Content-Type: application/x-www-form-urlencoded"
    )

    if [[ -n "$client_secret" ]]; then
        local basic_auth
        basic_auth=$(base64_basic_auth "$client_id" "$client_secret")
        curl_args+=(-H "Authorization: Basic $basic_auth")
    fi

    curl_args+=(-d "grant_type=$grant_type")

    while [[ $# -gt 0 ]]; do
        curl_args+=(-d "$1")
        shift
    done

    curl_args+=(-d "client_id=$client_id")

    curl "${curl_args[@]}" "$FITBIT_TOKEN_URL"
}

save_auth_tokens() {
    local client_id="$1"
    local client_secret="$2"
    local redirect_uri="$3"
    local scopes="$4"
    local response_json="$5"
    local fallback_refresh="${6:-}"

    local now_epoch
    now_epoch=$(date_epoch_now)

    local auth_json
    auth_json="$(python3 - "$client_id" "$client_secret" "$redirect_uri" "$scopes" "$response_json" "$fallback_refresh" "$now_epoch" <<'PY'
import json
import sys

client_id, client_secret, redirect_uri, scopes, response_json, fallback_refresh, now_epoch = sys.argv[1:8]
payload = json.loads(response_json)

access_token = payload.get("access_token")
if not access_token:
    raise SystemExit("Error: Fitbit token response did not contain access_token")

refresh_token = payload.get("refresh_token") or fallback_refresh
expires_in = int(payload.get("expires_in", 3600))
expires_at = int(now_epoch) + max(expires_in - 60, 60)

result = {
    "client_id": client_id,
    "client_secret": client_secret,
    "redirect_uri": redirect_uri,
    "scopes": scopes,
    "access_token": access_token,
    "refresh_token": refresh_token,
    "expires_at": expires_at,
    "token_type": payload.get("token_type", "Bearer"),
    "user_id": payload.get("user_id", ""),
    "last_auth_at": int(now_epoch),
}

print(json.dumps(result, indent=2, sort_keys=True))
PY
)"

    write_json_file "$FITBIT_AUTH_FILE" "$auth_json"
}

load_pending_field() {
    local key="$1"
    [[ -f "$FITBIT_PENDING_FILE" ]] || die "No pending Fitbit auth state found. Run $(basename "$0") auth-url first." "$EXIT_FILE_NOT_FOUND"
    json_get "$FITBIT_PENDING_FILE" "$key"
}

parse_redirect_input() {
    local raw_input="$1"

    python3 - "$raw_input" <<'PY'
import json
import sys
from urllib.parse import parse_qs, urlparse

raw = sys.argv[1].strip()
if "code=" in raw:
    parsed = urlparse(raw)
    params = parse_qs(parsed.query)
    print(json.dumps({
        "code": params.get("code", [""])[0],
        "state": params.get("state", [""])[0],
    }))
else:
    print(json.dumps({"code": raw, "state": ""}))
PY
}

refresh_access_token() {
    [[ -f "$FITBIT_AUTH_FILE" ]] || die "No Fitbit auth file found. Run $(basename "$0") auth first." "$EXIT_FILE_NOT_FOUND"

    local client_id client_secret refresh_token redirect_uri scopes response_json
    client_id="$(json_get "$FITBIT_AUTH_FILE" "client_id")"
    client_secret="$(json_get "$FITBIT_AUTH_FILE" "client_secret")"
    refresh_token="$(json_get "$FITBIT_AUTH_FILE" "refresh_token")"
    redirect_uri="$(json_get "$FITBIT_AUTH_FILE" "redirect_uri")"
    scopes="$(json_get "$FITBIT_AUTH_FILE" "scopes")"

    [[ -n "$client_id" && -n "$refresh_token" ]] || die "Fitbit auth file is missing client_id or refresh_token. Run auth again." "$EXIT_ERROR"

    response_json="$(token_request "refresh_token" "$client_id" "$client_secret" "refresh_token=$refresh_token")"
    save_auth_tokens "$client_id" "$client_secret" "$redirect_uri" "$scopes" "$response_json" "$refresh_token"
}

get_access_token() {
    [[ -f "$FITBIT_AUTH_FILE" ]] || die "No Fitbit auth file found. Run $(basename "$0") auth first." "$EXIT_FILE_NOT_FOUND"

    local access_token expires_at now_epoch
    access_token="$(json_get "$FITBIT_AUTH_FILE" "access_token")"
    expires_at="$(json_get "$FITBIT_AUTH_FILE" "expires_at")"
    now_epoch="$(date_epoch_now)"

    if [[ -n "$access_token" && -n "$expires_at" ]] && [[ "$now_epoch" -lt "$expires_at" ]]; then
        printf '%s' "$access_token"
        return 0
    fi

    refresh_access_token
    json_get "$FITBIT_AUTH_FILE" "access_token"
}

api_get() {
    local endpoint="$1"
    local token="$2"
    local response_raw http_code body

    response_raw="$(curl -sS -w $'\n%{http_code}' \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/json" \
        "$FITBIT_API_BASE$endpoint")"

    http_code="$(printf '%s\n' "$response_raw" | tail -n 1)"
    body="$(printf '%s\n' "$response_raw" | sed '$d')"

    if [[ "$http_code" == "401" ]]; then
        refresh_access_token >/dev/null
        token="$(json_get "$FITBIT_AUTH_FILE" "access_token")"
        response_raw="$(curl -sS -w $'\n%{http_code}' \
            -H "Authorization: Bearer $token" \
            -H "Accept: application/json" \
            "$FITBIT_API_BASE$endpoint")"
        http_code="$(printf '%s\n' "$response_raw" | tail -n 1)"
        body="$(printf '%s\n' "$response_raw" | sed '$d')"
    fi

    if [[ "$http_code" -ge 400 ]]; then
        echo "Fitbit API error (HTTP $http_code) for $endpoint" >&2
        echo "$body" >&2
        return 1
    fi

    printf '%s' "$body"
}

extract_metric_value() {
    local metric="$1"
    local response_json="$2"

    python3 - "$metric" "$response_json" <<'PY'
import json
import sys

metric, response_json = sys.argv[1:3]
payload = json.loads(response_json)

value = None
if metric == "steps":
    rows = payload.get("activities-steps", [])
    if rows:
        value = rows[0].get("value")
elif metric == "resting_heart_rate":
    rows = payload.get("activities-heart", [])
    if rows:
        value = rows[0].get("value", {}).get("restingHeartRate")
elif metric == "sleep_minutes":
    value = payload.get("summary", {}).get("totalMinutesAsleep")

if value is None or value == "":
    raise SystemExit(0)

print(value)
PY
}

merge_metric_updates() {
    local target_file="$1"
    local updates="$2"

    [[ -n "$updates" ]] || return 0

    local merged
    merged="$(python3 - "$target_file" "$updates" <<'PY'
import os
import sys

target_file, updates = sys.argv[1:3]
merged = {}

if os.path.exists(target_file):
    with open(target_file, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue
            parts = line.split("|", 1)
            if len(parts) == 2:
                merged[parts[0]] = parts[1]

for raw_line in updates.splitlines():
    line = raw_line.strip()
    if not line:
        continue
    parts = line.split("|", 1)
    if len(parts) != 2:
        continue
    merged[parts[0]] = parts[1]

for key in sorted(merged):
    print(f"{key}|{merged[key]}")
PY
)"

    write_json_file "$FITBIT_SYNC_STATE_FILE" "{\"last_sync_at\": $(date_epoch_now)}"
    atomic_write "$merged" "$target_file" || die "Failed to update $target_file" "$EXIT_ERROR"
    set_private_permissions "$target_file"
}

count_update_lines() {
    printf '%s\n' "$1" | awk 'NF {count++} END {print count+0}'
}

cmd_auth_url() {
    local client_id client_secret redirect_uri scopes code_challenge state auth_url

    client_id="$(resolve_client_id)"
    client_secret="$(resolve_client_secret)"
    redirect_uri="$FITBIT_REDIRECT_URI"
    scopes="$FITBIT_SCOPES"

    save_pending_auth "$client_id" "$client_secret" "$redirect_uri" "$scopes"
    code_challenge="$(load_pending_field "code_challenge")"
    state="$(load_pending_field "state")"
    auth_url="$(build_auth_url "$client_id" "$redirect_uri" "$scopes" "$code_challenge" "$state")"

    echo "$auth_url"
}

cmd_auth_exchange() {
    local redirect_input="${1:-}"
    [[ -n "$redirect_input" ]] || {
        read -rp "Paste the full Fitbit redirect URL (or the raw code): " redirect_input
    }
    redirect_input=$(sanitize_single_line "$redirect_input")
    [[ -n "$redirect_input" ]] || die "Fitbit auth exchange requires a redirect URL or code" "$EXIT_INVALID_ARGS"

    local parsed_json code returned_state expected_state client_id client_secret redirect_uri scopes code_verifier response_json
    parsed_json="$(parse_redirect_input "$redirect_input")"
    code="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("code",""))' <<<"$parsed_json")"
    returned_state="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("state",""))' <<<"$parsed_json")"
    expected_state="$(load_pending_field "state")"
    client_id="$(load_pending_field "client_id")"
    client_secret="$(load_pending_field "client_secret")"
    redirect_uri="$(load_pending_field "redirect_uri")"
    scopes="$(load_pending_field "scopes")"
    code_verifier="$(load_pending_field "code_verifier")"

    [[ -n "$code" ]] || die "Could not find an authorization code in the provided input." "$EXIT_INVALID_ARGS"
    if [[ -n "$returned_state" && "$returned_state" != "$expected_state" ]]; then
        die "Fitbit OAuth state mismatch. Start the auth flow again." "$EXIT_ERROR"
    fi

    response_json="$(token_request "authorization_code" "$client_id" "$client_secret" \
        "code=$code" \
        "redirect_uri=$redirect_uri" \
        "code_verifier=$code_verifier")"

    save_auth_tokens "$client_id" "$client_secret" "$redirect_uri" "$scopes" "$response_json"
    rm -f "$FITBIT_PENDING_FILE"
    echo "Fitbit authentication saved to $FITBIT_AUTH_FILE"
}

cmd_auth() {
    local auth_url
    auth_url="$(cmd_auth_url)"

    echo "1. Open this URL in your browser and approve access:"
    echo ""
    echo "   $auth_url"
    echo ""
    echo "2. Fitbit will redirect to: $FITBIT_REDIRECT_URI"
    echo "3. Paste the full redirect URL back here."
    echo ""

    local redirect_input
    read -rp "Redirect URL: " redirect_input
    cmd_auth_exchange "$redirect_input"
}

cmd_sync() {
    local days="${1:-$FITBIT_DEFAULT_DAYS}"
    validate_numeric "$days" "sync days" || die "Sync days must be a positive integer" "$EXIT_INVALID_ARGS"

    local access_token
    access_token="$(get_access_token)"

    local steps_updates=""
    local heart_updates=""
    local sleep_updates=""
    local offset day steps_json heart_json sleep_json steps_value heart_value sleep_value

    for (( offset=days-1; offset>=0; offset-- )); do
        day="$(date_days_ago "$offset" "%Y-%m-%d")"

        steps_json="$(api_get "/1/user/-/activities/steps/date/${day}/${day}/1min.json" "$access_token")"
        steps_value="$(extract_metric_value "steps" "$steps_json" || true)"
        if [[ -n "$steps_value" ]]; then
            steps_updates+="${day}|${steps_value}"$'\n'
        fi

        heart_json="$(api_get "/1/user/-/activities/heart/date/${day}/${day}/1min.json" "$access_token")"
        heart_value="$(extract_metric_value "resting_heart_rate" "$heart_json" || true)"
        if [[ -n "$heart_value" ]]; then
            heart_updates+="${day}|${heart_value}"$'\n'
        fi

        sleep_json="$(api_get "/1/user/-/sleep/date/${day}.json" "$access_token")"
        sleep_value="$(extract_metric_value "sleep_minutes" "$sleep_json" || true)"
        if [[ -n "$sleep_value" ]]; then
            sleep_updates+="${day}|${sleep_value}"$'\n'
        fi
    done

    merge_metric_updates "$FITBIT_DATA_DIR/steps.txt" "$steps_updates"
    merge_metric_updates "$FITBIT_DATA_DIR/resting_heart_rate.txt" "$heart_updates"
    merge_metric_updates "$FITBIT_DATA_DIR/sleep_minutes.txt" "$sleep_updates"

    echo "Synced Fitbit data for $days day(s)"
    echo "  steps: $(count_update_lines "$steps_updates") day(s)"
    echo "  resting_heart_rate: $(count_update_lines "$heart_updates") day(s)"
    echo "  sleep_minutes: $(count_update_lines "$sleep_updates") day(s)"
}

cmd_status() {
    local auth_ready="no"
    local client_id=""
    local expires_at=""
    local last_sync_at=""

    if [[ -f "$FITBIT_AUTH_FILE" ]]; then
        auth_ready="yes"
        client_id="$(json_get "$FITBIT_AUTH_FILE" "client_id")"
        expires_at="$(json_get "$FITBIT_AUTH_FILE" "expires_at")"
    fi
    if [[ -f "$FITBIT_SYNC_STATE_FILE" ]]; then
        last_sync_at="$(json_get "$FITBIT_SYNC_STATE_FILE" "last_sync_at")"
    fi

    echo "Fitbit auth ready: $auth_ready"
    [[ -n "$client_id" ]] && echo "Client ID: $client_id"
    [[ -n "$expires_at" ]] && echo "Token expiry epoch: $expires_at"
    [[ -n "$last_sync_at" ]] && echo "Last sync epoch: $last_sync_at"
    echo "Metric dir: $FITBIT_DATA_DIR"
}

cmd_latest() {
    "$SCRIPT_DIR/fitbit_import.sh" latest
}

main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        auth) cmd_auth "$@" ;;
        auth-url) cmd_auth_url "$@" ;;
        auth-exchange) cmd_auth_exchange "$@" ;;
        sync) cmd_sync "$@" ;;
        status) cmd_status ;;
        latest) cmd_latest ;;
        help|-h|--help) show_help ;;
        *)
            echo "Error: Unknown command '$cmd'" >&2
            show_help >&2
            exit "$EXIT_INVALID_ARGS"
            ;;
    esac
}

main "$@"
