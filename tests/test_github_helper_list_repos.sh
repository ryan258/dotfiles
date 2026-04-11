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
        http*)
            url="$1"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [ -n "${FAKE_CURL_LOG_FILE:-}" ] && [ -n "$url" ]; then
    printf '%s\n' "$url" >> "$FAKE_CURL_LOG_FILE"
fi

case "$url" in
    *"/user/repos?affiliation=owner&sort=pushed&per_page=100")
        case "${FAKE_CURL_OWNER_MODE:-success}" in
            success)
                cat "${FAKE_CURL_OWNER_FILE:?}" > "$out_file"
                ;;
            fail)
                echo "curl: (22) owner repo listing failed" >&2
                exit 22
                ;;
            *)
                echo "unsupported owner mode" >&2
                exit 64
                ;;
        esac
        ;;
    *"/users/"*"/repos?sort=pushed&per_page=100")
        case "${FAKE_CURL_PUBLIC_MODE:-success}" in
            success)
                cat "${FAKE_CURL_PUBLIC_FILE:?}" > "$out_file"
                ;;
            fail)
                echo "curl: (22) public repo listing failed" >&2
                exit 22
                ;;
            *)
                echo "unsupported public mode" >&2
                exit 64
                ;;
        esac
        ;;
    *)
        echo "unsupported fake curl url: $url" >&2
        exit 64
        ;;
esac
STUB
    chmod +x "$STUB_BIN_DIR/curl"
}

teardown() {
    teardown_test_environment
}

@test "list_repos prefers the authenticated owner listing so private repos are included" {
    export FAKE_CURL_OWNER_FILE="$TEST_DIR/repos-owner.json"
    export FAKE_CURL_PUBLIC_FILE="$TEST_DIR/repos-public.json"
    export FAKE_CURL_LOG_FILE="$TEST_DIR/curl.log"

    cat > "$FAKE_CURL_OWNER_FILE" <<'JSON'
[
  {"name":"components","private":true,"fork":false,"pushed_at":"2026-04-04T21:37:26Z"},
  {"name":"dotfiles","private":false,"fork":false,"pushed_at":"2026-04-03T20:40:07Z"}
]
JSON
    cat > "$FAKE_CURL_PUBLIC_FILE" <<'JSON'
[
  {"name":"dotfiles","private":false,"fork":false,"pushed_at":"2026-04-03T20:40:07Z"}
]
JSON

    run env \
        PATH="$STUB_BIN_DIR:$PATH" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        ENV_FILE="$TEST_DIR/missing.env" \
        GITHUB_TOKEN="test-token" \
        GITHUB_USERNAME="ryan258" \
        GITHUB_EXCLUDE_FORKS="false" \
        GITHUB_CACHE_DIR="$TEST_DIR/cache/github" \
        FAKE_CURL_OWNER_MODE="success" \
        FAKE_CURL_PUBLIC_MODE="success" \
        FAKE_CURL_OWNER_FILE="$FAKE_CURL_OWNER_FILE" \
        FAKE_CURL_PUBLIC_FILE="$FAKE_CURL_PUBLIC_FILE" \
        FAKE_CURL_LOG_FILE="$FAKE_CURL_LOG_FILE" \
        "$DOTFILES_DIR/scripts/github_helper.sh" list_repos

    [ "$status" -eq 0 ]
    [[ "$output" == *'"name": "components"'* ]]
    [[ "$output" == *'"name": "dotfiles"'* ]]
    grep -Fq "/user/repos?affiliation=owner&sort=pushed&per_page=100" "$FAKE_CURL_LOG_FILE"
    if grep -Fq "/users/ryan258/repos?sort=pushed&per_page=100" "$FAKE_CURL_LOG_FILE"; then
        echo "unexpected public fallback call"
        return 1
    fi
}

@test "list_repos falls back to the public listing when the authenticated owner call fails" {
    export FAKE_CURL_OWNER_FILE="$TEST_DIR/repos-owner.json"
    export FAKE_CURL_PUBLIC_FILE="$TEST_DIR/repos-public.json"
    export FAKE_CURL_LOG_FILE="$TEST_DIR/curl.log"

    cat > "$FAKE_CURL_OWNER_FILE" <<'JSON'
[
  {"name":"components","private":true,"fork":false,"pushed_at":"2026-04-04T21:37:26Z"}
]
JSON
    cat > "$FAKE_CURL_PUBLIC_FILE" <<'JSON'
[
  {"name":"dotfiles","private":false,"fork":false,"pushed_at":"2026-04-03T20:40:07Z"}
]
JSON

    run env \
        PATH="$STUB_BIN_DIR:$PATH" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        ENV_FILE="$TEST_DIR/missing.env" \
        GITHUB_TOKEN="test-token" \
        GITHUB_USERNAME="ryan258" \
        GITHUB_EXCLUDE_FORKS="false" \
        GITHUB_CACHE_DIR="$TEST_DIR/cache/github" \
        FAKE_CURL_OWNER_MODE="fail" \
        FAKE_CURL_PUBLIC_MODE="success" \
        FAKE_CURL_OWNER_FILE="$FAKE_CURL_OWNER_FILE" \
        FAKE_CURL_PUBLIC_FILE="$FAKE_CURL_PUBLIC_FILE" \
        FAKE_CURL_LOG_FILE="$FAKE_CURL_LOG_FILE" \
        "$DOTFILES_DIR/scripts/github_helper.sh" list_repos

    [ "$status" -eq 0 ]
    [[ "$output" == *'"name": "dotfiles"'* ]]
    [[ "$output" != *'"name": "components"'* ]]
    grep -Fq "/user/repos?affiliation=owner&sort=pushed&per_page=100" "$FAKE_CURL_LOG_FILE"
    grep -Fq "/users/ryan258/repos?sort=pushed&per_page=100" "$FAKE_CURL_LOG_FILE"
}
