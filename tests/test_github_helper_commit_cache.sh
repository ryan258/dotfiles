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
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o)
            out_file="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

case "${FAKE_CURL_MODE:-success}" in
    success|graphql_error)
        cat "${FAKE_CURL_RESPONSE_FILE:?}" > "$out_file"
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

@test "list_commits_for_date serves cached GraphQL data when refresh fails" {
    export FAKE_CURL_RESPONSE_FILE="$TEST_DIR/graphql-success.json"
    cat > "$FAKE_CURL_RESPONSE_FILE" <<'JSON'
{
  "data": {
    "user": {
      "repositories": {
        "nodes": [
          {
            "name": "dotfiles",
            "defaultBranchRef": {
              "target": {
                "history": {
                  "nodes": [
                    {
                      "oid": "abcdef1234567890",
                      "messageHeadline": "Fix cache fallback"
                    }
                  ]
                }
              }
            }
          }
        ]
      }
    }
  }
}
JSON

    run env \
        PATH="$STUB_BIN_DIR:$PATH" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        ENV_FILE="$TEST_DIR/missing.env" \
        GITHUB_TOKEN="test-token" \
        GITHUB_USERNAME="ryan258" \
        GITHUB_EXCLUDE_FORKS="false" \
        GITHUB_CACHE_DIR="$TEST_DIR/cache/github" \
        FAKE_CURL_MODE="success" \
        FAKE_CURL_RESPONSE_FILE="$FAKE_CURL_RESPONSE_FILE" \
        "$DOTFILES_DIR/scripts/github_helper.sh" list_commits_for_date 2026-03-29

    [ "$status" -eq 0 ]
    [ "$output" = "dotfiles|abcdef1|Fix cache fallback" ]

    cache_count="$(find "$TEST_DIR/cache/github" -type f | wc -l | tr -d ' ')"
    [ "${cache_count:-0}" -ge 1 ]

    run env \
        PATH="$STUB_BIN_DIR:$PATH" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        ENV_FILE="$TEST_DIR/missing.env" \
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

@test "list_commits_for_date fails on GraphQL error payloads when no cache exists" {
    export FAKE_CURL_RESPONSE_FILE="$TEST_DIR/graphql-error.json"
    cat > "$FAKE_CURL_RESPONSE_FILE" <<'JSON'
{
  "errors": [
    {
      "message": "Bad credentials"
    }
  ]
}
JSON

    run env \
        PATH="$STUB_BIN_DIR:$PATH" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        ENV_FILE="$TEST_DIR/missing.env" \
        GITHUB_TOKEN="test-token" \
        GITHUB_USERNAME="ryan258" \
        GITHUB_EXCLUDE_FORKS="false" \
        GITHUB_CACHE_DIR="$TEST_DIR/cache/github" \
        FAKE_CURL_MODE="graphql_error" \
        FAKE_CURL_RESPONSE_FILE="$FAKE_CURL_RESPONSE_FILE" \
        "$DOTFILES_DIR/scripts/github_helper.sh" list_commits_for_date 2026-03-29

    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: GitHub GraphQL returned an error for commit activity"* ]]
}
