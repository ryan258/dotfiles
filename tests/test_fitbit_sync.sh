#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment

    export DOTFILES_DIR
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    export FITBIT_CLIENT_ID="test-client"
    export FITBIT_CLIENT_SECRET="test-secret"
    export FITBIT_REDIRECT_URI="http://127.0.0.1:8765/callback"

    mkdir -p "$TEST_DIR/fake-bin"
}

teardown() {
    teardown_test_environment
}

@test "fitbit_sync.sh auth-url creates pending PKCE state and prints authorize URL" {
    run env PATH="$TEST_DIR/fake-bin:$PATH" "$DOTFILES_DIR/scripts/fitbit_sync.sh" auth-url

    [ "$status" -eq 0 ]
    [[ "$output" == https://www.fitbit.com/oauth2/authorize* ]]
    [[ "$output" == *"client_id=test-client"* ]]
    assert_file_exists "$DOTFILES_DATA_DIR/fitbit_oauth_pending.json"
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit_oauth_pending.json" "\"code_verifier\""
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit_oauth_pending.json" "\"state\""
}

@test "fitbit_sync.sh auth-exchange saves OAuth tokens from Fitbit token response" {
    cat > "$TEST_DIR/fake-bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s' '{"access_token":"access-123","refresh_token":"refresh-123","expires_in":3600,"token_type":"Bearer","user_id":"user-1"}'
EOF
    chmod +x "$TEST_DIR/fake-bin/curl"

    run env PATH="$TEST_DIR/fake-bin:$PATH" "$DOTFILES_DIR/scripts/fitbit_sync.sh" auth-url
    [ "$status" -eq 0 ]

    state="$(python3 - "$DOTFILES_DATA_DIR/fitbit_oauth_pending.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    print(json.load(handle)["state"])
PY
)"

    redirect_url="http://127.0.0.1:8765/callback?code=auth-code-abc&state=$state"
    run env PATH="$TEST_DIR/fake-bin:$PATH" "$DOTFILES_DIR/scripts/fitbit_sync.sh" auth-exchange "$redirect_url"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Fitbit authentication saved"* ]]
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit_oauth.json" "\"access_token\": \"access-123\""
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit_oauth.json" "\"refresh_token\": \"refresh-123\""
    [ ! -f "$DOTFILES_DATA_DIR/fitbit_oauth_pending.json" ]
}

@test "fitbit_sync.sh sync writes local metric files from mocked API responses" {
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

body='{}'
if [[ "$url" == "https://api.fitbit.com/oauth2/token" ]]; then
  body='{"access_token":"refreshed-access","refresh_token":"refreshed-refresh","expires_in":3600,"token_type":"Bearer","user_id":"user-1"}'
elif [[ "$url" == *"/activities/steps/date/"* ]]; then
  body="{\"activities-steps\":[{\"dateTime\":\"${MOCK_DAY}\",\"value\":\"6789\"}]}"
elif [[ "$url" == *"/activities/heart/date/"* ]]; then
  body="{\"activities-heart\":[{\"dateTime\":\"${MOCK_DAY}\",\"value\":{\"restingHeartRate\":61}}]}"
elif [[ "$url" == *"/sleep/date/"* ]]; then
  body="{\"summary\":{\"totalMinutesAsleep\":430}}"
fi

if [[ "$wants_http_code" == "true" ]]; then
  printf '%s\n200' "$body"
else
  printf '%s' "$body"
fi
EOF
    chmod +x "$TEST_DIR/fake-bin/curl"

    cat > "$DOTFILES_DATA_DIR/fitbit_oauth.json" <<EOF
{
  "access_token": "cached-access",
  "client_id": "test-client",
  "client_secret": "test-secret",
  "expires_at": 9999999999,
  "redirect_uri": "http://127.0.0.1:8765/callback",
  "refresh_token": "refresh-123",
  "scopes": "activity heartrate sleep profile"
}
EOF

    run env PATH="$TEST_DIR/fake-bin:$PATH" MOCK_DAY="$MOCK_DAY" "$DOTFILES_DIR/scripts/fitbit_sync.sh" sync 1

    [ "$status" -eq 0 ]
    [[ "$output" == *"Synced Fitbit data for 1 day(s)"* ]]
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit/steps.txt" "$mock_day|6789"
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit/resting_heart_rate.txt" "$mock_day|61"
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit/sleep_minutes.txt" "$mock_day|430"
}
