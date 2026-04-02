#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    export DOTFILES_DIR
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export STUB_BIN_DIR="$TEST_DIR/bin"
    mkdir -p "$STUB_BIN_DIR" "$TEST_DIR/cache/github"

    cat > "$STUB_BIN_DIR/curl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

out_file=""
url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o)
            out_file="$2"
            shift 2
            ;;
        *)
            url="$1"
            shift
            ;;
    esac
done

case "${FAKE_CURL_MODE:-success}" in
    success)
        case "$url" in
            *"/user/events?per_page=100"|*"/users/"*"/events?per_page=100")
                cat "${FAKE_CURL_EVENTS_FILE:?}" > "$out_file"
                ;;
            *"/repos/"*"/commits/"*)
                cat "${FAKE_CURL_COMMIT_FILE:?}" > "$out_file"
                ;;
            *)
                echo "unsupported fake curl url: $url" >&2
                exit 64
                ;;
        esac
        ;;
    fail)
        echo "curl: (6) Could not resolve host: api.github.com" >&2
        exit 6
        ;;
    *)
        echo "unsupported fake curl mode" >&2
        exit 64
        ;;
esac
STUB
    chmod +x "$STUB_BIN_DIR/curl"
}

teardown() {
    teardown_test_environment
}

@test "list_commits_for_date serves cached branch push data when refresh fails" {
    export FAKE_CURL_EVENTS_FILE="$TEST_DIR/events-success.json"
    export FAKE_CURL_COMMIT_FILE="$TEST_DIR/commit-success.json"
    cat > "$FAKE_CURL_EVENTS_FILE" <<'JSON'
[
  {
    "type": "PushEvent",
    "created_at": "2026-03-29T12:00:00Z",
    "repo": {
      "name": "ryan258/dotfiles"
    },
    "payload": {
      "head": "abcdef1234567890",
      "ref": "refs/heads/feature-branch"
    }
  }
]
JSON
    cat > "$FAKE_CURL_COMMIT_FILE" <<'JSON'
{
  "commit": {
    "message": "Fix cache fallback\n\nMore detail"
  }
}
JSON

    run env \
        PATH="$STUB_BIN_DIR:$PATH" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        ENV_FILE="$TEST_DIR/missing.env" \
        TZ="UTC" \
        GITHUB_TOKEN="test-token" \
        GITHUB_USERNAME="ryan258" \
        GITHUB_EXCLUDE_FORKS="false" \
        GITHUB_CACHE_DIR="$TEST_DIR/cache/github" \
        FAKE_CURL_MODE="success" \
        "$DOTFILES_DIR/scripts/github_helper.sh" list_commits_for_date 2026-03-29

    [ "$status" -eq 0 ]
    [ "$output" = "dotfiles|abcdef1|Fix cache fallback" ]

    cache_count="$(find "$TEST_DIR/cache/github" -type f | wc -l | tr -d ' ')"
    [ "${cache_count:-0}" -ge 1 ]

    run env \
        PATH="$STUB_BIN_DIR:$PATH" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        ENV_FILE="$TEST_DIR/missing.env" \
        TZ="UTC" \
        GITHUB_TOKEN="test-token" \
        GITHUB_USERNAME="ryan258" \
        GITHUB_EXCLUDE_FORKS="false" \
        GITHUB_CACHE_DIR="$TEST_DIR/cache/github" \
        FAKE_CURL_MODE="fail" \
        "$DOTFILES_DIR/scripts/github_helper.sh" list_commits_for_date 2026-03-29

    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning: Unable to refresh GitHub commit activity for 2026-03-29. Serving cached data."* ]]
    [[ "$output" == *"dotfiles|abcdef1|Fix cache fallback"* ]]
}

@test "list_commits_for_date fails when both events endpoints return invalid data and no cache exists" {
    export FAKE_CURL_EVENTS_FILE="$TEST_DIR/events-invalid.json"
    cat > "$FAKE_CURL_EVENTS_FILE" <<'JSON'
{"not":"an array"
JSON

    run env \
        PATH="$STUB_BIN_DIR:$PATH" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        ENV_FILE="$TEST_DIR/missing.env" \
        TZ="UTC" \
        GITHUB_TOKEN="test-token" \
        GITHUB_USERNAME="ryan258" \
        GITHUB_EXCLUDE_FORKS="false" \
        GITHUB_CACHE_DIR="$TEST_DIR/cache/github" \
        FAKE_CURL_MODE="success" \
        "$DOTFILES_DIR/scripts/github_helper.sh" list_commits_for_date 2026-03-29

    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Failed to reach GitHub events API"* ]]
}
