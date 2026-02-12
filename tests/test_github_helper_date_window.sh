#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    export DOTFILES_DIR
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    export WINDOW_FUNC_FILE="$TEST_DIR/utc_window_fn.sh"
    awk '
        /^_utc_window_for_local_date\(\)/ { capture=1 }
        capture { print }
        capture && /^}$/ { exit }
    ' "$DOTFILES_DIR/scripts/github_helper.sh" > "$WINDOW_FUNC_FILE"
}

teardown() {
    teardown_test_environment
}

@test "_utc_window_for_local_date uses next local midnight on DST spring-forward day" {
    run bash -c "source '$DOTFILES_DIR/scripts/lib/date_utils.sh'; source '$WINDOW_FUNC_FILE'; export TZ='America/Los_Angeles'; _utc_window_for_local_date '2026-03-08'"
    [ "$status" -eq 0 ]

    start_epoch="$(printf '%s\n' "$output" | sed -n '3p')"
    end_epoch="$(printf '%s\n' "$output" | sed -n '4p')"

    run bash -c "source '$DOTFILES_DIR/scripts/lib/date_utils.sh'; export TZ='America/Los_Angeles'; date_shift_from '2026-03-08' 0 '%s'; date_shift_from '2026-03-09' 0 '%s'"
    [ "$status" -eq 0 ]

    expected_start="$(printf '%s\n' "$output" | sed -n '1p')"
    expected_end="$(printf '%s\n' "$output" | sed -n '2p')"

    [ "$start_epoch" -eq "$expected_start" ]
    [ "$end_epoch" -eq "$expected_end" ]
    [ $((end_epoch - start_epoch)) -eq 82800 ]
}
