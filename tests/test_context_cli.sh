#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"

setup() {
    setup_test_environment
    CONTEXT_SCRIPT="$BATS_TEST_DIRNAME/../scripts/context.sh"
}

teardown() {
    teardown_test_environment
}

@test "context.sh capture creates a context snapshot" {
    run bash -c "cd \"$TEST_DIR\" && \"$CONTEXT_SCRIPT\" capture cli-test"
    [ "$status" -eq 0 ]
    [ -d "$DOTFILES_DATA_DIR/contexts/cli-test" ]
    [ -f "$DOTFILES_DATA_DIR/contexts/cli-test/timestamp.txt" ]
}

@test "context.sh list shows saved contexts" {
    run bash -c "cd \"$TEST_DIR\" && \"$CONTEXT_SCRIPT\" capture list-test"
    [ "$status" -eq 0 ]

    run bash "$CONTEXT_SCRIPT" list
    [[ "$output" =~ "list-test" ]]
}

@test "context.sh show/path/restore return expected output" {
    run bash -c "cd \"$TEST_DIR\" && \"$CONTEXT_SCRIPT\" capture show-test"
    [ "$status" -eq 0 ]

    run bash "$CONTEXT_SCRIPT" show show-test
    [[ "$output" =~ "Context: show-test" ]]
    [[ "$output" =~ "$TEST_DIR" ]]

    run bash "$CONTEXT_SCRIPT" path show-test
    [ "$output" = "$TEST_DIR" ]

    run bash "$CONTEXT_SCRIPT" restore show-test
    [[ "$output" == *"cd \"$TEST_DIR\""* ]]
    [[ "$output" =~ "Tip:" ]]
}
