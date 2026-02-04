#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"

setup() {
    setup_test_environment
    ARCHIVE_SCRIPT="$BATS_TEST_DIRNAME/../scripts/archive_manager.sh"
    touch "$TEST_DIR/sample.txt"
}

teardown() {
    teardown_test_environment
}

@test "archive_manager create rejects unsupported format" {
    run bash -c "cd \"$TEST_DIR\" && \"$ARCHIVE_SCRIPT\" create archive.bad sample.txt 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Unsupported format" ]]
}

@test "archive_manager create fails on missing file" {
    run bash -c "cd \"$TEST_DIR\" && \"$ARCHIVE_SCRIPT\" create archive.zip missing.txt 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "File not found" ]]
}

@test "archive_manager extract fails on missing archive" {
    run bash -c "cd \"$TEST_DIR\" && \"$ARCHIVE_SCRIPT\" extract missing.zip 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Archive file not found" ]]
}

@test "archive_manager list fails on missing archive" {
    run bash -c "cd \"$TEST_DIR\" && \"$ARCHIVE_SCRIPT\" list missing.zip 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Archive file not found" ]]
}
