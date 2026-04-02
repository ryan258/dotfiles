#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

local_now_utc_iso() {
    python3 - <<'PY'
from datetime import datetime, timezone

print(datetime.now().astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
}

local_yesterday_late_utc_iso() {
    python3 - <<'PY'
from datetime import datetime, timedelta, timezone

now = datetime.now().astimezone()
yesterday_late = (now - timedelta(days=1)).replace(hour=23, minute=30, second=0, microsecond=0)
print(yesterday_late.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
}

setup() {
    setup_test_environment
    export DOTFILES_DIR="$TEST_DIR/dotfiles"
    mkdir -p "$DOTFILES_DIR/scripts/lib"

    cp "$BATS_TEST_DIRNAME/../scripts/lib/github_ops.sh" "$DOTFILES_DIR/scripts/lib/github_ops.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/date_utils.sh" "$DOTFILES_DIR/scripts/lib/date_utils.sh"

    cat > "$DOTFILES_DIR/scripts/github_helper.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    list_commits_for_date)
        if [ -n "${GITHUB_COMMITS_FIXTURE:-}" ] && [ -f "$GITHUB_COMMITS_FIXTURE" ]; then
            cat "$GITHUB_COMMITS_FIXTURE"
            exit 0
        fi
        case "${GITHUB_HELPER_MODE:-empty}" in
            empty)
                exit 0
                ;;
            commit)
                printf '%s\n' "dotfiles|abcdef1|Fix cache fallback"
                ;;
            fail)
                echo "Error: helper failed" >&2
                exit 1
                ;;
        esac
        ;;
    list_repos)
        if [ -n "${GITHUB_REPOS_FIXTURE:-}" ] && [ -f "$GITHUB_REPOS_FIXTURE" ]; then
            cat "$GITHUB_REPOS_FIXTURE"
        else
            echo "[]"
        fi
        ;;
    *)
        exit 0
        ;;
esac
STUB
    chmod +x "$DOTFILES_DIR/scripts/github_helper.sh"
}

teardown() {
    teardown_test_environment
}

@test "get_commit_activity_for_date treats empty helper output as a successful no-commit day" {
    run env DOTFILES_DIR="$DOTFILES_DIR" bash -lc "source '$DOTFILES_DIR/scripts/lib/date_utils.sh'; source '$DOTFILES_DIR/scripts/lib/github_ops.sh'; get_commit_activity_for_date '2026-03-29'"

    [ "$status" -eq 0 ]
    [ "$output" = "  (No commits for 2026-03-29)" ]
}

@test "get_commit_activity_for_date formats helper commit output" {
    run env GITHUB_HELPER_MODE=commit DOTFILES_DIR="$DOTFILES_DIR" bash -lc "source '$DOTFILES_DIR/scripts/lib/date_utils.sh'; source '$DOTFILES_DIR/scripts/lib/github_ops.sh'; get_commit_activity_for_date '2026-03-29'"

    [ "$status" -eq 0 ]
    [ "$output" = "  • dotfiles: Fix cache fallback (abcdef1)" ]
}

@test "get_recent_github_activity filters inactive repos from recent pushes" {
    local repos_fixture="$TEST_DIR/repos.json"
    local inactive_file="$TEST_DIR/inactive.txt"
    local today_iso

    today_iso="$(local_now_utc_iso)"

    cat > "$repos_fixture" <<EOF
[
  {"name":"dotfiles","pushed_at":"$today_iso"},
  {"name":"rockit","pushed_at":"$today_iso"}
]
EOF
    printf '%s\n' "dotfiles|2026-03-30|good place" > "$inactive_file"

    run env \
        DOTFILES_DIR="$DOTFILES_DIR" \
        GITHUB_REPOS_FIXTURE="$repos_fixture" \
        GITHUB_INACTIVE_REPOS_FILE="$inactive_file" \
        bash -lc "source '$DOTFILES_DIR/scripts/lib/date_utils.sh'; source '$DOTFILES_DIR/scripts/lib/github_ops.sh'; get_recent_github_activity 7"

    [ "$status" -eq 0 ]
    [[ "$output" == *"rockit"* ]]
    [[ "$output" != *"dotfiles"* ]]
}

@test "get_recent_github_activity labels pushes by local calendar day instead of rolling 24 hours" {
    local repos_fixture="$TEST_DIR/repos-yesterday.json"
    local yesterday_late_iso

    yesterday_late_iso="$(local_yesterday_late_utc_iso)"

    cat > "$repos_fixture" <<EOF
[
  {"name":"dotfiles","pushed_at":"$yesterday_late_iso"}
]
EOF

    run env \
        TZ="America/Chicago" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        GITHUB_REPOS_FIXTURE="$repos_fixture" \
        bash -lc "source '$DOTFILES_DIR/scripts/lib/date_utils.sh'; source '$DOTFILES_DIR/scripts/lib/github_ops.sh'; get_recent_github_activity 7"

    [ "$status" -eq 0 ]
    [[ "$output" == "  • dotfiles (pushed yesterday)" ]]
}

@test "get_commit_activity_for_date filters inactive repos from commit recap" {
    local commits_fixture="$TEST_DIR/commits.txt"
    local inactive_file="$TEST_DIR/inactive.txt"

    cat > "$commits_fixture" <<'EOF'
dotfiles|abcdef1|Fix cache fallback
rockit|1234567|Ship the thing
EOF
    printf '%s\n' "dotfiles|2026-03-30|good place" > "$inactive_file"

    run env \
        DOTFILES_DIR="$DOTFILES_DIR" \
        GITHUB_COMMITS_FIXTURE="$commits_fixture" \
        GITHUB_INACTIVE_REPOS_FILE="$inactive_file" \
        bash -lc "source '$DOTFILES_DIR/scripts/lib/date_utils.sh'; source '$DOTFILES_DIR/scripts/lib/github_ops.sh'; get_commit_activity_for_date '2026-03-29'"

    [ "$status" -eq 0 ]
    [[ "$output" == "  • rockit: Ship the thing (1234567)" ]]
}
