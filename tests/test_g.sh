#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    # Alias for backward compatibility with test assertions
    export TEST_DATA_DIR="$TEST_DIR"
}

teardown() {
    teardown_test_environment
}

@test "g.sh reports missing bookmarks file" {
    run bash -c "$BATS_TEST_DIRNAME/../scripts/g.sh missing-bookmark 2>&1"

    [ "$status" -eq 1 ]
    [[ "$output" =~ "No bookmarks saved" ]]
}
