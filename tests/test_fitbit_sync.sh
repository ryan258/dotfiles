#!/usr/bin/env bats

# test_fitbit_sync.sh - Bats coverage for fitbit sync.

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment

    export DOTFILES_DIR
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export ENV_FILE="$TEST_DIR/nonexistent.env"

    export GOOGLE_HEALTH_CLIENT_ID="test-client"
    export GOOGLE_HEALTH_CLIENT_SECRET="test-secret"
    export GOOGLE_HEALTH_REDIRECT_URI="https://www.google.com"

    mkdir -p "$TEST_DIR/fake-bin"
}

teardown() {
    teardown_test_environment
}

@test "fitbit_sync.sh auth-url creates pending state and prints authorize URL" {
    run env PATH="$TEST_DIR/fake-bin:$PATH" "$DOTFILES_DIR/scripts/fitbit_sync.sh" auth-url

    [ "$status" -eq 0 ]
    [[ "$output" == https://accounts.google.com/o/oauth2/v2/auth* ]]
    [[ "$output" == *"client_id=test-client"* ]]
    [[ "$output" == *"access_type=offline"* ]]
    assert_file_exists "$DOTFILES_DATA_DIR/google_health_oauth_pending.json"
    assert_file_contains "$DOTFILES_DATA_DIR/google_health_oauth_pending.json" "\"state\""
}

@test "fitbit_sync.sh auth-url ignores a corrupted stored auth file" {
    : > "$DOTFILES_DATA_DIR/google_health_oauth.json"

    run env PATH="$TEST_DIR/fake-bin:$PATH" "$DOTFILES_DIR/scripts/fitbit_sync.sh" auth-url

    [ "$status" -eq 0 ]
    [[ "$output" == https://accounts.google.com/o/oauth2/v2/auth* ]]
    assert_file_exists "$DOTFILES_DATA_DIR/google_health_oauth_pending.json"
}

@test "fitbit_sync.sh auth-exchange saves OAuth tokens and identity metadata" {
    cat > "$TEST_DIR/fake-bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

url="${@: -1}"
wants_http_code="false"
for arg in "$@"; do
  if [[ "$arg" == *"%{http_code}"* ]]; then
    wants_http_code="true"
  fi
done

body='{}'

if [[ "$url" == "https://oauth2.googleapis.com/token" ]]; then
  body='{"access_token":"access-123","refresh_token":"refresh-123","expires_in":3600,"token_type":"Bearer","scope":"https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly"}'
elif [[ "$url" == "https://health.googleapis.com/v4/users/me/identity" ]]; then
  body='{"legacyUserId":"legacy-1","healthUserId":"health-1"}'
fi

if [[ "$wants_http_code" == "true" ]]; then
  printf '%s\n200' "$body"
else
  printf '%s' "$body"
fi
EOF
    chmod +x "$TEST_DIR/fake-bin/curl"

    run env PATH="$TEST_DIR/fake-bin:$PATH" "$DOTFILES_DIR/scripts/fitbit_sync.sh" auth-url
    [ "$status" -eq 0 ]

    state="$(python3 - "$DOTFILES_DATA_DIR/google_health_oauth_pending.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    print(json.load(handle)["state"])
PY
)"

    redirect_url="https://www.google.com/?code=auth-code-abc&state=$state"
    run env PATH="$TEST_DIR/fake-bin:$PATH" "$DOTFILES_DIR/scripts/fitbit_sync.sh" auth-exchange "$redirect_url"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Fitbit sync authentication saved"* ]]
    assert_file_contains "$DOTFILES_DATA_DIR/google_health_oauth.json" "\"access_token\": \"access-123\""
    assert_file_contains "$DOTFILES_DATA_DIR/google_health_oauth.json" "\"refresh_token\": \"refresh-123\""
    assert_file_contains "$DOTFILES_DATA_DIR/google_health_oauth.json" "\"legacy_user_id\": \"legacy-1\""
    assert_file_contains "$DOTFILES_DATA_DIR/google_health_oauth.json" "\"health_user_id\": \"health-1\""
    [ ! -f "$DOTFILES_DATA_DIR/google_health_oauth_pending.json" ]
}

@test "fitbit_sync.sh sync writes local metric files from mocked Google Health responses" {
    mock_day="$(date '+%Y-%m-%d')"
    export MOCK_DAY="$mock_day"

    cat > "$TEST_DIR/fake-bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

url="${@: -1}"
wants_http_code="false"
for arg in "$@"; do
  if [[ "$arg" == *"%{http_code}"* ]]; then
    wants_http_code="true"
  fi
done

year="${MOCK_DAY%%-*}"
month_day="${MOCK_DAY#*-}"
month="${month_day%%-*}"
day="${MOCK_DAY##*-}"

body='{}'
if [[ "$url" == *"/dataTypes/steps/dataPoints:dailyRollUp" ]]; then
  body="{\"rollupDataPoints\":[{\"civilStartTime\":{\"date\":{\"year\":${year#0},\"month\":${month#0},\"day\":${day#0}},\"time\":{}},\"steps\":{\"countSum\":\"6789\"}}]}"
elif [[ "$url" == *"/dataTypes/sleep/dataPoints:reconcile"* ]]; then
  body="{\"dataPoints\":[{\"sleep\":{\"interval\":{\"endTime\":\"${MOCK_DAY}T07:30:00Z\"},\"metadata\":{\"main\":true},\"summary\":{\"minutesAsleep\":\"430\"}}}]}"
elif [[ "$url" == *"/dataTypes/daily-resting-heart-rate/dataPoints"* ]]; then
  body="{\"dataPoints\":[{\"dailyRestingHeartRate\":{\"date\":{\"year\":${year#0},\"month\":${month#0},\"day\":${day#0}},\"beatsPerMinute\":61}}]}"
elif [[ "$url" == *"/dataTypes/daily-heart-rate-variability/dataPoints"* ]]; then
  body="{\"dataPoints\":[{\"dailyHeartRateVariability\":{\"date\":{\"year\":${year#0},\"month\":${month#0},\"day\":${day#0}},\"rmssdMillis\":42}}]}"
fi

if [[ "$wants_http_code" == "true" ]]; then
  printf '%s\n200' "$body"
else
  printf '%s' "$body"
fi
EOF
    chmod +x "$TEST_DIR/fake-bin/curl"

    cat > "$DOTFILES_DATA_DIR/google_health_oauth.json" <<EOF
{
  "access_token": "cached-access",
  "client_id": "test-client",
  "client_secret": "test-secret",
  "expires_at": 9999999999,
  "redirect_uri": "https://www.google.com",
  "refresh_token": "refresh-123",
  "scopes": "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly https://www.googleapis.com/auth/googlehealth.sleep.readonly"
}
EOF

    run env PATH="$TEST_DIR/fake-bin:$PATH" MOCK_DAY="$MOCK_DAY" "$DOTFILES_DIR/scripts/fitbit_sync.sh" sync 1

    [ "$status" -eq 0 ]
    [[ "$output" == *"Synced Fitbit data for 1 day(s)"* ]]
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit/steps.txt" "$mock_day|6789"
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit/sleep_minutes.txt" "$mock_day|430"
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit/resting_heart_rate.txt" "$mock_day|61"
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit/hrv.txt" "$mock_day|42"
}

@test "fitbit_metrics.py extracts normalized daily values directly" {
    run bash -lc "cat <<'JSON' | python3 '$DOTFILES_DIR/scripts/fitbit_metrics.py' steps
{\"rollupDataPoints\":[{\"civilStartTime\":{\"date\":{\"year\":2026,\"month\":4,\"day\":23}},\"steps\":{\"countSum\":\"6789\"}}]}
JSON"
    [ "$status" -eq 0 ]
    [ "$output" = "2026-04-23|6789" ]

    run bash -lc "cat <<'JSON' | python3 '$DOTFILES_DIR/scripts/fitbit_metrics.py' sleep_minutes
{\"dataPoints\":[{\"sleep\":{\"interval\":{\"endTime\":\"2026-04-23T07:30:00Z\"},\"metadata\":{\"main\":true},\"summary\":{\"minutesAsleep\":\"430\"}}}]}
JSON"
    [ "$status" -eq 0 ]
    [ "$output" = "2026-04-23|430" ]

    run bash -lc "cat <<'JSON' | python3 '$DOTFILES_DIR/scripts/fitbit_metrics.py' resting_heart_rate
{\"dataPoints\":[{\"dailyRestingHeartRate\":{\"date\":{\"year\":2026,\"month\":4,\"day\":23},\"beatsPerMinute\":61}}]}
JSON"
    [ "$status" -eq 0 ]
    [ "$output" = "2026-04-23|61" ]

    run bash -lc "cat <<'JSON' | python3 '$DOTFILES_DIR/scripts/fitbit_metrics.py' hrv
{\"dataPoints\":[{\"dailyHeartRateVariability\":{\"date\":{\"year\":2026,\"month\":4,\"day\":23},\"rmssdMillis\":42}}]}
JSON"
    [ "$status" -eq 0 ]
    [ "$output" = "2026-04-23|42" ]
}

@test "fitbit_sync.sh sync surfaces OAuth refresh failures and stores the sync error" {
    cat > "$TEST_DIR/fake-bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

url="${@: -1}"

if [[ "$url" == "https://oauth2.googleapis.com/token" ]]; then
  printf '%s' '{"error":"invalid_grant","error_description":"Token has been expired or revoked."}'
else
  printf '%s' '{}'
fi
EOF
    chmod +x "$TEST_DIR/fake-bin/curl"

    cat > "$DOTFILES_DATA_DIR/google_health_oauth.json" <<EOF
{
  "access_token": "stale-access",
  "client_id": "test-client",
  "client_secret": "test-secret",
  "expires_at": 1,
  "redirect_uri": "https://www.google.com",
  "refresh_token": "refresh-123",
  "scopes": "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly https://www.googleapis.com/auth/googlehealth.sleep.readonly"
}
EOF

    run env PATH="$TEST_DIR/fake-bin:$PATH" "$DOTFILES_DIR/scripts/fitbit_sync.sh" sync 1

    [ "$status" -ne 0 ]
    [[ "$output" == *"Google Health token refresh failed: invalid_grant (Token has been expired or revoked.)"* ]]
    assert_file_contains "$DOTFILES_DATA_DIR/google_health_sync_state.json" "\"last_sync_error\": \"Google Health token refresh failed: invalid_grant (Token has been expired or revoked.)\""
}

@test "fitbit_sync.sh status reports an empty auth file without crashing" {
    : > "$DOTFILES_DATA_DIR/google_health_oauth.json"

    run env PATH="$TEST_DIR/fake-bin:$PATH" "$DOTFILES_DIR/scripts/fitbit_sync.sh" status

    [ "$status" -eq 0 ]
    [[ "$output" == *"Fitbit sync auth ready: no"* ]]
    [[ "$output" == *"Auth file issue: Auth file is empty or invalid JSON."* ]]
    [[ "$output" != *"JSONDecodeError"* ]]
}

@test "fitbit_sync.sh sync fails fast with a clear error for an empty auth file" {
    : > "$DOTFILES_DATA_DIR/google_health_oauth.json"

    run env PATH="$TEST_DIR/fake-bin:$PATH" "$DOTFILES_DIR/scripts/fitbit_sync.sh" sync 1

    [ "$status" -eq 1 ]
    [[ "$output" == *"Fitbit sync auth file is empty or invalid JSON"* ]]
    [[ "$output" != *"JSONDecodeError"* ]]
}
