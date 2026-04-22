#!/usr/bin/env bats

# test_drive.sh - Bats coverage for drive helper.

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    export TEST_DATA_DIR="$TEST_DIR/.config/dotfiles-data"
}

teardown() {
    teardown_test_environment
}

_drive_script() {
    printf '%s' "$BATS_TEST_DIRNAME/../scripts/drive.sh"
}

_future_epoch() {
    python3 - <<'PY'
import time
print(int(time.time()) + 3600)
PY
}

_expired_epoch() {
    python3 - <<'PY'
import time
print(int(time.time()) - 10)
PY
}

_write_valid_token() {
    cat > "$TEST_DATA_DIR/google_drive_token_cache.json" <<EOF
{"access_token":"token-123","expiry":$(_future_epoch)}
EOF
}

_write_expired_token() {
    cat > "$TEST_DATA_DIR/google_drive_token_cache.json" <<EOF
{"access_token":"expired-token","expiry":$(_expired_epoch)}
EOF
}

_write_creds() {
    cat > "$TEST_DATA_DIR/google_drive_creds.json" <<'EOF'
{"client_id":"client-id","client_secret":"client-secret","refresh_token":"refresh-123"}
EOF
}

@test "drive status reports configured auth token and cache state" {
    _write_creds
    _write_valid_token
    mkdir -p "$HOME/.cache/dotfiles"
    cat > "$HOME/.cache/dotfiles/google_drive_search_cache.json" <<'EOF'
{"recent:test":{"fetched_at_epoch":1,"payload":[]}}
EOF

    run bash "$(_drive_script)" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Auth: configured"* ]]
    [[ "$output" == *"Token: valid"* ]]
    [[ "$output" == *"Cache: available"* ]]
}

@test "drive recent uses current focus and cache to avoid repeat API calls" {
    local mock_bin="$TEST_DIR/bin"
    mkdir -p "$mock_bin"
    _write_valid_token
    echo "Strategy dashboard memo" > "$TEST_DATA_DIR/daily_focus.txt"

    cat > "$mock_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
count_file="${CURL_COUNT_FILE:?missing}"
count="$(cat "$count_file" 2>/dev/null || echo 0)"
count=$((count + 1))
echo "$count" > "$count_file"
cat <<'JSON'
{"files":[
  {"id":"1","name":"Strategy dashboard memo","mimeType":"application/vnd.google-apps.document","modifiedTime":"2026-04-22T10:00:00Z","viewedByMeTime":"2026-04-22T11:00:00Z","webViewLink":"https://example.com/1"},
  {"id":"2","name":"Dashboard follow-up notes","mimeType":"application/vnd.google-apps.document","modifiedTime":"2026-04-21T10:00:00Z","viewedByMeTime":"2026-04-21T11:00:00Z","webViewLink":"https://example.com/2"},
  {"id":"3","name":"Completely unrelated file","mimeType":"application/vnd.google-apps.document","modifiedTime":"2026-04-20T10:00:00Z","viewedByMeTime":"2026-04-20T11:00:00Z","webViewLink":"https://example.com/3"}
]}
JSON
EOF
    chmod +x "$mock_bin/curl"
    echo "0" > "$TEST_DIR/curl_count.txt"

    run env PATH="$mock_bin:$PATH" CURL_COUNT_FILE="$TEST_DIR/curl_count.txt" bash "$(_drive_script)" recent 7 --json
    [ "$status" -eq 0 ]
    [[ "$output" == *"Strategy dashboard memo"* ]]
    [[ "$output" == *"Dashboard follow-up notes"* ]]
    [[ "$output" != *"Completely unrelated file"* ]]
    [ "$(cat "$TEST_DIR/curl_count.txt")" -eq 1 ]

    run env PATH="$mock_bin:$PATH" CURL_COUNT_FILE="$TEST_DIR/curl_count.txt" bash "$(_drive_script)" recent 7 --json
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_DIR/curl_count.txt")" -eq 1 ]
}

@test "drive recall uses current focus when no query is provided" {
    local mock_bin="$TEST_DIR/bin"
    mkdir -p "$mock_bin"
    _write_valid_token
    echo "Architecture review memo" > "$TEST_DATA_DIR/daily_focus.txt"

    cat > "$mock_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'JSON'
{"files":[
  {"id":"1","name":"Architecture review memo","mimeType":"application/vnd.google-apps.document","modifiedTime":"2026-04-18T10:00:00Z","viewedByMeTime":"2026-04-22T11:00:00Z","webViewLink":"https://example.com/1"},
  {"id":"2","name":"Review checklist","mimeType":"application/vnd.google-apps.document","modifiedTime":"2026-04-17T10:00:00Z","viewedByMeTime":"2026-04-21T11:00:00Z","webViewLink":"https://example.com/2"}
]}
JSON
EOF
    chmod +x "$mock_bin/curl"

    run env PATH="$mock_bin:$PATH" bash "$(_drive_script)" recall --json
    [ "$status" -eq 0 ]
    [[ "$output" == *"Architecture review memo"* ]]
}

@test "drive refreshes an expired token before recall" {
    local mock_bin="$TEST_DIR/bin"
    mkdir -p "$mock_bin"
    _write_creds
    _write_expired_token
    echo "Strategy memo" > "$TEST_DATA_DIR/daily_focus.txt"

    cat > "$mock_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == *"oauth2.googleapis.com/token"* ]]; then
  cat <<'JSON'
{"access_token":"fresh-token","expires_in":3600}
JSON
else
  cat <<'JSON'
{"files":[
  {"id":"1","name":"Strategy memo","mimeType":"application/vnd.google-apps.document","modifiedTime":"2026-04-22T10:00:00Z","viewedByMeTime":"2026-04-22T11:00:00Z","webViewLink":"https://example.com/1"}
]}
JSON
fi
EOF
    chmod +x "$mock_bin/curl"

    run env PATH="$mock_bin:$PATH" bash "$(_drive_script)" recall --json
    [ "$status" -eq 0 ]
    [[ "$output" == *"Strategy memo"* ]]
    [[ "$(cat "$TEST_DATA_DIR/google_drive_token_cache.json")" == *"fresh-token"* ]]
}

@test "drive auth saves credentials and token via loopback flow" {
    local mock_bin="$TEST_DIR/bin"
    mkdir -p "$mock_bin"

    cat > "$mock_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'JSON'
{"access_token":"fresh-token","refresh_token":"refresh-456","expires_in":3600}
JSON
EOF
    chmod +x "$mock_bin/curl"

    cat > "$mock_bin/nc" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-z" ]]; then
  exit 1
fi
cat >/dev/null
printf 'GET /?code=auth-code-123&scope=drive HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n'
EOF
    chmod +x "$mock_bin/nc"

    run bash -c "printf 'client-id\nclient-secret\n' | PATH='$mock_bin:$PATH' OSTYPE='linux-gnu' bash '$(_drive_script)' auth"
    [ "$status" -eq 0 ]
    [[ "$(cat "$TEST_DATA_DIR/google_drive_creds.json")" == *"refresh-456"* ]]
    [[ "$(cat "$TEST_DATA_DIR/google_drive_token_cache.json")" == *"fresh-token"* ]]
}

@test "drive read falls back to alt=media when export is unavailable" {
    local mock_bin="$TEST_DIR/bin"
    mkdir -p "$mock_bin"
    _write_valid_token

    cat > "$mock_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == *"/export?mimeType=text/plain"* ]]; then
  cat <<'JSON'
{"error":{"code":403,"message":"Export only supports Docs editors files."}}
JSON
else
  printf 'Fallback file contents'
fi
EOF
    chmod +x "$mock_bin/curl"

    run env PATH="$mock_bin:$PATH" bash "$(_drive_script)" read file-123
    [ "$status" -eq 0 ]
    [ "$output" = "Fallback file contents" ]
}
