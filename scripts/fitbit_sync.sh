#!/usr/bin/env bash
set -euo pipefail

# fitbit_sync.sh - Sync Fitbit data via the Google Health API into local metric files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_lib "config.sh"
require_lib "date_utils.sh"

require_cmd "curl" "Install curl"
require_cmd "python3" "Install Python 3"

ensure_data_dirs

GOOGLE_HEALTH_AUTH_FILE="${GOOGLE_HEALTH_AUTH_FILE:-$DATA_DIR/google_health_oauth.json}"
GOOGLE_HEALTH_PENDING_FILE="${GOOGLE_HEALTH_PENDING_FILE:-$DATA_DIR/google_health_oauth_pending.json}"
GOOGLE_HEALTH_SYNC_STATE_FILE="${GOOGLE_HEALTH_SYNC_STATE_FILE:-$DATA_DIR/google_health_sync_state.json}"
FITBIT_DATA_DIR="${FITBIT_DATA_DIR:-$DATA_DIR/fitbit}"
GOOGLE_HEALTH_CLIENT_ID="${GOOGLE_HEALTH_CLIENT_ID:-}"
GOOGLE_HEALTH_CLIENT_SECRET="${GOOGLE_HEALTH_CLIENT_SECRET:-}"
GOOGLE_HEALTH_REDIRECT_URI="${GOOGLE_HEALTH_REDIRECT_URI:-https://www.google.com}"
GOOGLE_HEALTH_SCOPES="${GOOGLE_HEALTH_SCOPES:-https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly https://www.googleapis.com/auth/googlehealth.sleep.readonly}"
GOOGLE_HEALTH_DEFAULT_DAYS="${GOOGLE_HEALTH_DEFAULT_DAYS:-7}"

readonly GOOGLE_HEALTH_AUTHORIZE_URL="https://accounts.google.com/o/oauth2/v2/auth"
readonly GOOGLE_HEALTH_TOKEN_URL="https://oauth2.googleapis.com/token"
readonly GOOGLE_HEALTH_API_BASE="https://health.googleapis.com/v4"
readonly GOOGLE_HEALTH_SLEEP_SOURCE_FAMILY="users/me/dataSourceFamilies/google-wearables"

mkdir -p "$FITBIT_DATA_DIR"
chmod 700 "$FITBIT_DATA_DIR" 2>/dev/null || true

show_help() {
    cat <<EOF
Usage: $(basename "$0") {auth|auth-url|auth-exchange|sync|status|latest|help}

Commands:
  auth
      Interactive helper. Builds a Google OAuth authorization URL, then
      exchanges the returned code for Fitbit data sync tokens.

  auth-url
      Print an OAuth authorization URL and save the pending auth state locally.

  auth-exchange <redirect_url_or_code>
      Exchange a Google OAuth redirect URL or raw authorization code for
      tokens, then store both the Google Health user ID and Fitbit legacy ID
      when available.

  sync [days]
      Pull Fitbit data for the last N days (default: $GOOGLE_HEALTH_DEFAULT_DAYS)
      through the Google Health API and write normalized daily metrics under
      ~/.config/dotfiles-data/fitbit/.

  status
      Show Fitbit sync auth and sync status.

  latest
      Show the newest local wearable metric values.

Environment:
  GOOGLE_HEALTH_CLIENT_ID
  GOOGLE_HEALTH_CLIENT_SECRET
  GOOGLE_HEALTH_REDIRECT_URI
  GOOGLE_HEALTH_SCOPES
  GOOGLE_HEALTH_DEFAULT_DAYS

Notes:
  - Register the redirect URI in your Google Cloud OAuth client before auth.
  - This script targets the Google Health API, not the legacy Fitbit Web API.
  - During Google OAuth testing mode, refresh tokens can expire after 7 days.
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
import json
import secrets
import sys

client_id, client_secret, redirect_uri, scopes = sys.argv[1:5]
state = secrets.token_urlsafe(24)

print(json.dumps({
    "client_id": client_id,
    "client_secret": client_secret,
    "redirect_uri": redirect_uri,
    "scopes": scopes,
    "state": state,
}, indent=2, sort_keys=True))
PY
)"

    write_json_file "$GOOGLE_HEALTH_PENDING_FILE" "$pending_json"
}

build_auth_url() {
    local client_id="$1"
    local redirect_uri="$2"
    local scopes="$3"
    local state="$4"

    python3 - "$client_id" "$redirect_uri" "$scopes" "$state" "$GOOGLE_HEALTH_AUTHORIZE_URL" <<'PY'
import sys
from urllib.parse import urlencode

client_id, redirect_uri, scopes, state, base_url = sys.argv[1:6]
params = urlencode({
    "response_type": "code",
    "client_id": client_id,
    "redirect_uri": redirect_uri,
    "scope": scopes,
    "access_type": "offline",
    "include_granted_scopes": "true",
    "prompt": "consent",
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
    local value="${GOOGLE_HEALTH_CLIENT_ID:-}"
    if [[ -z "$value" ]]; then
        value="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "client_id")"
    fi
    value=$(prompt_if_missing "$value" "Enter Google Health OAuth Client ID: ")
    [[ -n "$value" ]] || die "Google Health Client ID is required" "$EXIT_INVALID_ARGS"
    printf '%s' "$value"
}

resolve_client_secret() {
    local value="${GOOGLE_HEALTH_CLIENT_SECRET:-}"
    if [[ -z "$value" ]]; then
        value="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "client_secret")"
    fi
    value=$(prompt_if_missing "$value" "Enter Google Health Client Secret: " true)
    [[ -n "$value" ]] || die "Google Health Client Secret is required" "$EXIT_INVALID_ARGS"
    printf '%s' "$value"
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
        -d "grant_type=$grant_type"
        -d "client_id=$client_id"
        -d "client_secret=$client_secret"
    )

    while [[ $# -gt 0 ]]; do
        curl_args+=(-d "$1")
        shift
    done

    curl "${curl_args[@]}" "$GOOGLE_HEALTH_TOKEN_URL"
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

    local existing_legacy_user_id existing_health_user_id
    existing_legacy_user_id="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "legacy_user_id")"
    existing_health_user_id="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "health_user_id")"

    local auth_json
    auth_json="$(python3 - "$client_id" "$client_secret" "$redirect_uri" "$scopes" "$response_json" "$fallback_refresh" "$now_epoch" "$existing_legacy_user_id" "$existing_health_user_id" <<'PY'
import json
import sys

(
    client_id,
    client_secret,
    redirect_uri,
    scopes,
    response_json,
    fallback_refresh,
    now_epoch,
    legacy_user_id,
    health_user_id,
) = sys.argv[1:10]
payload = json.loads(response_json)

access_token = payload.get("access_token")
if not access_token:
    raise SystemExit("Error: Google Health token response did not contain access_token")

refresh_token = payload.get("refresh_token") or fallback_refresh
expires_in = int(payload.get("expires_in", 3600))
expires_at = int(now_epoch) + max(expires_in - 60, 60)

result = {
    "client_id": client_id,
    "client_secret": client_secret,
    "redirect_uri": redirect_uri,
    "scopes": payload.get("scope") or scopes,
    "access_token": access_token,
    "refresh_token": refresh_token,
    "expires_at": expires_at,
    "token_type": payload.get("token_type", "Bearer"),
    "legacy_user_id": legacy_user_id,
    "health_user_id": health_user_id,
    "last_auth_at": int(now_epoch),
}

print(json.dumps(result, indent=2, sort_keys=True))
PY
)"

    write_json_file "$GOOGLE_HEALTH_AUTH_FILE" "$auth_json"
}

load_pending_field() {
    local key="$1"
    [[ -f "$GOOGLE_HEALTH_PENDING_FILE" ]] || die "No pending Fitbit auth state found. Run $(basename "$0") auth-url first." "$EXIT_FILE_NOT_FOUND"
    json_get "$GOOGLE_HEALTH_PENDING_FILE" "$key"
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
    [[ -f "$GOOGLE_HEALTH_AUTH_FILE" ]] || die "No Fitbit sync auth file found. Run $(basename "$0") auth first." "$EXIT_FILE_NOT_FOUND"

    local client_id client_secret refresh_token redirect_uri scopes response_json
    client_id="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "client_id")"
    client_secret="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "client_secret")"
    refresh_token="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "refresh_token")"
    redirect_uri="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "redirect_uri")"
    scopes="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "scopes")"

    [[ -n "$client_id" && -n "$client_secret" && -n "$refresh_token" ]] || die "Fitbit sync auth file is missing client_id, client_secret, or refresh_token. Run auth again." "$EXIT_ERROR"

    response_json="$(token_request "refresh_token" "$client_id" "$client_secret" "refresh_token=$refresh_token")"
    save_auth_tokens "$client_id" "$client_secret" "$redirect_uri" "$scopes" "$response_json" "$refresh_token"
}

get_access_token() {
    [[ -f "$GOOGLE_HEALTH_AUTH_FILE" ]] || die "No Fitbit sync auth file found. Run $(basename "$0") auth first." "$EXIT_FILE_NOT_FOUND"

    local access_token expires_at now_epoch
    access_token="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "access_token")"
    expires_at="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "expires_at")"
    now_epoch="$(date_epoch_now)"

    if [[ -n "$access_token" && -n "$expires_at" ]] && [[ "$now_epoch" -lt "$expires_at" ]]; then
        printf '%s' "$access_token"
        return 0
    fi

    refresh_access_token
    json_get "$GOOGLE_HEALTH_AUTH_FILE" "access_token"
}

run_api_call() {
    local method="$1"
    local endpoint="$2"
    local token="$3"
    local request_body="${4:-}"

    local curl_args=(
        -sS
        -w $'\n%{http_code}'
        -X "$method"
        -H "Authorization: Bearer $token"
        -H "Accept: application/json"
    )

    if [[ "$method" != "GET" ]]; then
        curl_args+=(-H "Content-Type: application/json")
    fi
    if [[ -n "$request_body" ]]; then
        curl_args+=(-d "$request_body")
    fi

    curl "${curl_args[@]}" "$GOOGLE_HEALTH_API_BASE$endpoint"
}

api_request() {
    local method="$1"
    local endpoint="$2"
    local token="$3"
    local request_body="${4:-}"
    local response_raw http_code response_body

    response_raw="$(run_api_call "$method" "$endpoint" "$token" "$request_body")"
    http_code="$(printf '%s\n' "$response_raw" | tail -n 1)"
    response_body="$(printf '%s\n' "$response_raw" | sed '$d')"

    if [[ "$http_code" == "401" ]]; then
        refresh_access_token >/dev/null
        token="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "access_token")"
        response_raw="$(run_api_call "$method" "$endpoint" "$token" "$request_body")"
        http_code="$(printf '%s\n' "$response_raw" | tail -n 1)"
        response_body="$(printf '%s\n' "$response_raw" | sed '$d')"
    fi

    if [[ "$http_code" -ge 400 ]]; then
        echo "Google Health API error (HTTP $http_code) for $endpoint" >&2
        echo "$response_body" >&2
        return 1
    fi

    printf '%s' "$response_body"
}

api_get() {
    local endpoint="$1"
    local token="$2"
    api_request "GET" "$endpoint" "$token"
}

api_post_json() {
    local endpoint="$1"
    local token="$2"
    local request_body="$3"
    api_request "POST" "$endpoint" "$token" "$request_body"
}

save_identity_metadata() {
    local access_token="$1"
    local identity_json
    identity_json="$(api_get "/users/me/identity" "$access_token" || true)"
    [[ -n "$identity_json" ]] || return 0

    local auth_json
    auth_json="$(python3 - "$GOOGLE_HEALTH_AUTH_FILE" "$identity_json" <<'PY'
import json
import os
import sys

auth_path, identity_json = sys.argv[1:3]
if not os.path.exists(auth_path):
    raise SystemExit(0)

with open(auth_path, "r", encoding="utf-8") as handle:
    auth = json.load(handle)
identity = json.loads(identity_json)

auth["legacy_user_id"] = identity.get("legacyUserId", auth.get("legacy_user_id", ""))
auth["health_user_id"] = identity.get("healthUserId", auth.get("health_user_id", ""))

print(json.dumps(auth, indent=2, sort_keys=True))
PY
)"

    [[ -n "$auth_json" ]] || return 0
    write_json_file "$GOOGLE_HEALTH_AUTH_FILE" "$auth_json"
}

metric_output_path() {
    local metric="${1:-}"

    case "$metric" in
        steps) echo "$FITBIT_DATA_DIR/steps.txt" ;;
        sleep_minutes) echo "$FITBIT_DATA_DIR/sleep_minutes.txt" ;;
        resting_heart_rate) echo "$FITBIT_DATA_DIR/resting_heart_rate.txt" ;;
        hrv) echo "$FITBIT_DATA_DIR/hrv.txt" ;;
        *)
            echo "Error: Unsupported Fitbit sync metric '$metric'" >&2
            return 1
            ;;
    esac
}

build_steps_daily_rollup_body() {
    local start_day="$1"
    local end_day="$2"

    python3 - "$start_day" "$end_day" <<'PY'
import json
import sys
from datetime import datetime

start_day, end_day = sys.argv[1:3]
start = datetime.strptime(start_day, "%Y-%m-%d")
end = datetime.strptime(end_day, "%Y-%m-%d")

print(json.dumps({
    "range": {
        "start": {
            "date": {"year": start.year, "month": start.month, "day": start.day},
            "time": {"hours": 0, "minutes": 0, "seconds": 0, "nanos": 0},
        },
        "end": {
            "date": {"year": end.year, "month": end.month, "day": end.day},
            "time": {"hours": 23, "minutes": 59, "seconds": 59, "nanos": 0},
        },
    },
    "windowSizeDays": 1,
}, sort_keys=True))
PY
}

build_sleep_endpoint() {
    local start_day="$1"

    python3 - "$GOOGLE_HEALTH_SLEEP_SOURCE_FAMILY" "$start_day" <<'PY'
import sys
from urllib.parse import urlencode

source_family, start_day = sys.argv[1:3]
params = urlencode({
    "dataSourceFamily": source_family,
    "filter": f'sleep.interval.civil_end_time >= "{start_day}"',
})
print(f"/users/me/dataTypes/sleep/dataPoints:reconcile?{params}")
PY
}

build_daily_metric_endpoint() {
    local endpoint_id="$1"
    local filter_field="$2"
    local start_day="$3"

    python3 - "$endpoint_id" "$filter_field" "$start_day" <<'PY'
import sys
from urllib.parse import urlencode

endpoint_id, filter_field, start_day = sys.argv[1:4]
params = urlencode({
    "filter": f'{filter_field} >= "{start_day}"',
})
print(f"/users/me/dataTypes/{endpoint_id}/dataPoints?{params}")
PY
}

extract_metric_updates() {
    local metric="$1"
    local response_json="$2"

    python3 - "$metric" "$response_json" <<'PY'
import json
import re
import sys
from datetime import datetime

metric, response_json = sys.argv[1:3]
payload = json.loads(response_json) if response_json.strip() else {}
points = payload.get("rollupDataPoints") or payload.get("dataPoints") or []


def coerce_number(value):
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        cleaned = value.replace(",", "").strip()
        if re.fullmatch(r"-?\d+(?:\.\d+)?", cleaned):
            return float(cleaned)
    return None


def format_value(value):
    rounded = round(value)
    if abs(value - rounded) < 1e-9:
        return str(int(rounded))
    return f"{value:.2f}".rstrip("0").rstrip(".")


def parse_day_from_dict(date_dict):
    if not isinstance(date_dict, dict):
        return None
    year = date_dict.get("year")
    month = date_dict.get("month")
    day = date_dict.get("day")
    if year is None or month is None or day is None:
        return None
    try:
        return f"{int(year):04d}-{int(month):02d}-{int(day):02d}"
    except (TypeError, ValueError):
        return None


def parse_day_from_iso(raw):
    if not raw:
        return None
    text = str(raw).strip()
    match = re.search(r"(\d{4}-\d{2}-\d{2})", text)
    if match:
        return match.group(1)
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).strftime("%Y-%m-%d")
    except ValueError:
        return None


def walk_dicts(obj):
    if isinstance(obj, dict):
        yield obj
        for value in obj.values():
            yield from walk_dicts(value)
    elif isinstance(obj, list):
        for value in obj:
            yield from walk_dicts(value)


def walk_numeric(obj, path=()):
    if isinstance(obj, dict):
        for key, value in obj.items():
            yield from walk_numeric(value, path + (str(key),))
    elif isinstance(obj, list):
        for value in obj:
            yield from walk_numeric(value, path)
    else:
        number = coerce_number(obj)
        if number is not None:
            yield path, number


def pick_day(item):
    if metric == "sleep_minutes":
        interval = item.get("sleep", {}).get("interval", {})
        for key in ("endTime", "startTime"):
            day = parse_day_from_iso(interval.get(key))
            if day:
                return day

    for candidate in walk_dicts(item):
        if "date" in candidate:
            day = parse_day_from_dict(candidate.get("date"))
            if day:
                return day

    for candidate in walk_dicts(item):
        for key in ("endTime", "startTime", "physicalTime"):
            day = parse_day_from_iso(candidate.get(key))
            if day:
                return day

    return None


def pick_generic_value(item, container_names, preferred_terms):
    containers = []
    for name in container_names:
        candidate = item.get(name)
        if isinstance(candidate, dict):
            containers.append(candidate)
    if not containers:
        containers = [item]

    excluded_terms = {"year", "month", "day", "hours", "minutes", "seconds", "nanos"}
    flattened = []
    for container in containers:
        flattened.extend(walk_numeric(container))

    for term in preferred_terms:
        for path, value in flattened:
            joined = ".".join(part.lower() for part in path)
            if term in joined and not any(excluded in joined for excluded in excluded_terms):
                return value

    for path, value in flattened:
        joined = ".".join(part.lower() for part in path)
        if not any(excluded in joined for excluded in excluded_terms):
            return value

    return None


if metric == "steps":
    updates = {}
    for item in points:
        day = pick_day(item)
        value = coerce_number(item.get("steps", {}).get("countSum"))
        if value is None:
            value = coerce_number(item.get("steps", {}).get("count"))
        if day and value is not None:
            updates[day] = value
    for day in sorted(updates):
        print(f"{day}|{format_value(updates[day])}")
elif metric == "sleep_minutes":
    updates = {}
    priorities = {}
    for item in points:
        sleep = item.get("sleep", {})
        day = pick_day(item)
        value = coerce_number(sleep.get("summary", {}).get("minutesAsleep"))
        if day is None or value is None:
            continue
        priority = 1 if sleep.get("metadata", {}).get("main") else 0
        current_priority = priorities.get(day, -1)
        current_value = updates.get(day, -1)
        if priority > current_priority or (priority == current_priority and value > current_value):
            priorities[day] = priority
            updates[day] = value
    for day in sorted(updates):
        print(f"{day}|{format_value(updates[day])}")
elif metric == "resting_heart_rate":
    updates = {}
    for item in points:
        day = pick_day(item)
        value = pick_generic_value(
            item,
            ("dailyRestingHeartRate", "restingHeartRate", "heartRate"),
            ("restingheartrate", "resting_heart_rate", "beatsperminute", "bpm", "value"),
        )
        if day and value is not None:
            updates[day] = value
    for day in sorted(updates):
        print(f"{day}|{format_value(updates[day])}")
elif metric == "hrv":
    updates = {}
    for item in points:
        day = pick_day(item)
        value = pick_generic_value(
            item,
            ("dailyHeartRateVariability", "heartRateVariability"),
            ("rmssd", "milliseconds", "millis", "value"),
        )
        if day and value is not None:
            updates[day] = value
    for day in sorted(updates):
        print(f"{day}|{format_value(updates[day])}")
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

    write_json_file "$GOOGLE_HEALTH_SYNC_STATE_FILE" "{\"last_sync_at\": $(date_epoch_now)}"
    atomic_write "$merged" "$target_file" || die "Failed to update $target_file" "$EXIT_ERROR"
    set_private_permissions "$target_file"
}

count_update_lines() {
    printf '%s\n' "$1" | awk 'NF {count++} END {print count+0}'
}

sync_metric() {
    local metric="$1"
    local days="$2"
    local access_token="$3"
    local required="${4:-true}"

    local start_day end_day endpoint request_body response_json updates target_file
    start_day="$(date_days_ago "$((days - 1))" "%Y-%m-%d")"
    end_day="$(date_today)"

    case "$metric" in
        steps)
            request_body="$(build_steps_daily_rollup_body "$start_day" "$end_day")"
            if ! response_json="$(api_post_json "/users/me/dataTypes/steps/dataPoints:dailyRollUp" "$access_token" "$request_body")"; then
                [[ "$required" == "true" ]] && return 1
                echo "Warning: Failed to sync $metric from Google Health API" >&2
                return 0
            fi
            ;;
        sleep_minutes)
            endpoint="$(build_sleep_endpoint "$start_day")"
            if ! response_json="$(api_get "$endpoint" "$access_token")"; then
                [[ "$required" == "true" ]] && return 1
                echo "Warning: Failed to sync $metric from Google Health API" >&2
                return 0
            fi
            ;;
        resting_heart_rate)
            endpoint="$(build_daily_metric_endpoint "daily-resting-heart-rate" "daily_resting_heart_rate.date" "$start_day")"
            if ! response_json="$(api_get "$endpoint" "$access_token")"; then
                echo "Warning: Failed to sync $metric from Google Health API" >&2
                return 0
            fi
            ;;
        hrv)
            endpoint="$(build_daily_metric_endpoint "daily-heart-rate-variability" "daily_heart_rate_variability.date" "$start_day")"
            if ! response_json="$(api_get "$endpoint" "$access_token")"; then
                echo "Warning: Failed to sync $metric from Google Health API" >&2
                return 0
            fi
            ;;
        *)
            die "Unsupported Fitbit sync metric '$metric'" "$EXIT_INVALID_ARGS"
            ;;
    esac

    updates="$(extract_metric_updates "$metric" "$response_json" || true)"
    target_file="$(metric_output_path "$metric")"
    merge_metric_updates "$target_file" "$updates"
    printf '%s' "$(count_update_lines "$updates")"
}

cmd_auth_url() {
    local client_id client_secret redirect_uri scopes state auth_url

    client_id="$(resolve_client_id)"
    client_secret="$(resolve_client_secret)"
    redirect_uri="$GOOGLE_HEALTH_REDIRECT_URI"
    scopes="$GOOGLE_HEALTH_SCOPES"

    save_pending_auth "$client_id" "$client_secret" "$redirect_uri" "$scopes"
    state="$(load_pending_field "state")"
    auth_url="$(build_auth_url "$client_id" "$redirect_uri" "$scopes" "$state")"

    echo "$auth_url"
}

cmd_auth_exchange() {
    local redirect_input="${1:-}"
    [[ -n "$redirect_input" ]] || {
        read -rp "Paste the full Google redirect URL (or the raw code): " redirect_input
    }
    redirect_input=$(sanitize_single_line "$redirect_input")
    [[ -n "$redirect_input" ]] || die "Fitbit sync auth exchange requires a redirect URL or code" "$EXIT_INVALID_ARGS"

    local parsed_json code returned_state expected_state client_id client_secret redirect_uri scopes response_json access_token
    parsed_json="$(parse_redirect_input "$redirect_input")"
    code="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("code",""))' <<<"$parsed_json")"
    returned_state="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("state",""))' <<<"$parsed_json")"
    expected_state="$(load_pending_field "state")"
    client_id="$(load_pending_field "client_id")"
    client_secret="$(load_pending_field "client_secret")"
    redirect_uri="$(load_pending_field "redirect_uri")"
    scopes="$(load_pending_field "scopes")"

    [[ -n "$code" ]] || die "Could not find an authorization code in the provided input." "$EXIT_INVALID_ARGS"
    if [[ -n "$returned_state" && "$returned_state" != "$expected_state" ]]; then
        die "Google OAuth state mismatch. Start the auth flow again." "$EXIT_ERROR"
    fi

    response_json="$(token_request "authorization_code" "$client_id" "$client_secret" \
        "code=$code" \
        "redirect_uri=$redirect_uri")"

    save_auth_tokens "$client_id" "$client_secret" "$redirect_uri" "$scopes" "$response_json"
    access_token="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "access_token")"
    if [[ -n "$access_token" ]]; then
        save_identity_metadata "$access_token" || true
    fi
    rm -f "$GOOGLE_HEALTH_PENDING_FILE"
    echo "Fitbit sync authentication saved to $GOOGLE_HEALTH_AUTH_FILE"
}

cmd_auth() {
    local auth_url
    auth_url="$(cmd_auth_url)"

    echo "1. Open this URL in your browser and approve access:"
    echo ""
    echo "   $auth_url"
    echo ""
    echo "2. Google will redirect to: $GOOGLE_HEALTH_REDIRECT_URI"
    echo "3. Paste the full redirect URL back here."
    echo ""

    local redirect_input
    read -rp "Redirect URL: " redirect_input
    cmd_auth_exchange "$redirect_input"
}

cmd_sync() {
    local days="${1:-$GOOGLE_HEALTH_DEFAULT_DAYS}"
    validate_numeric "$days" "sync days" || die "Sync days must be a positive integer" "$EXIT_INVALID_ARGS"
    (( days >= 1 )) || die "Sync days must be at least 1" "$EXIT_INVALID_ARGS"

    local access_token
    access_token="$(get_access_token)"

    local steps_count sleep_count resting_count hrv_count
    steps_count="$(sync_metric "steps" "$days" "$access_token" "true")"
    sleep_count="$(sync_metric "sleep_minutes" "$days" "$access_token" "true")"
    resting_count="$(sync_metric "resting_heart_rate" "$days" "$access_token" "false")"
    hrv_count="$(sync_metric "hrv" "$days" "$access_token" "false")"

    echo "Synced Fitbit data for $days day(s)"
    echo "  steps: ${steps_count:-0} day(s)"
    echo "  sleep_minutes: ${sleep_count:-0} day(s)"
    echo "  resting_heart_rate: ${resting_count:-0} day(s)"
    echo "  hrv: ${hrv_count:-0} day(s)"
}

cmd_status() {
    local auth_ready="no"
    local client_id=""
    local expires_at=""
    local last_sync_at=""
    local legacy_user_id=""
    local health_user_id=""

    if [[ -f "$GOOGLE_HEALTH_AUTH_FILE" ]]; then
        auth_ready="yes"
        client_id="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "client_id")"
        expires_at="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "expires_at")"
        legacy_user_id="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "legacy_user_id")"
        health_user_id="$(json_get "$GOOGLE_HEALTH_AUTH_FILE" "health_user_id")"
    fi
    if [[ -f "$GOOGLE_HEALTH_SYNC_STATE_FILE" ]]; then
        last_sync_at="$(json_get "$GOOGLE_HEALTH_SYNC_STATE_FILE" "last_sync_at")"
    fi

    echo "Fitbit sync auth ready: $auth_ready"
    [[ -n "$client_id" ]] && echo "Client ID: $client_id"
    [[ -n "$legacy_user_id" ]] && echo "Fitbit legacy user ID: $legacy_user_id"
    [[ -n "$health_user_id" ]] && echo "Google Health user ID: $health_user_id"
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
