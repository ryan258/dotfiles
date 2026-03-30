#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    export DOTFILES_DIR="$TEST_DIR/dotfiles"
    mkdir -p "$DOTFILES_DIR/scripts/lib"

    cp "$BATS_TEST_DIRNAME/../scripts/lib/github_ops.sh" "$DOTFILES_DIR/scripts/lib/github_ops.sh"

    cat > "$DOTFILES_DIR/scripts/github_helper.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    list_commits_for_date)
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
    run env DOTFILES_DIR="$DOTFILES_DIR" bash -lc "source '$DOTFILES_DIR/scripts/lib/github_ops.sh'; get_commit_activity_for_date '2026-03-29'"

    [ "$status" -eq 0 ]
    [ "$output" = "  (No commits for 2026-03-29)" ]
}

@test "get_commit_activity_for_date formats helper commit output" {
    run env GITHUB_HELPER_MODE=commit DOTFILES_DIR="$DOTFILES_DIR" bash -lc "source '$DOTFILES_DIR/scripts/lib/github_ops.sh'; get_commit_activity_for_date '2026-03-29'"

    [ "$status" -eq 0 ]
    [ "$output" = "  • dotfiles: Fix cache fallback (abcdef1)" ]
}
