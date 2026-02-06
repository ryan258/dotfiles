#!/usr/bin/env bats

setup() {
    export TEST_DIR
    TEST_DIR="$(mktemp -d)"
    export TEST_FILE="$TEST_DIR/test_atomic_ops.txt"

    # shellcheck disable=SC1090
    source "$BATS_TEST_DIRNAME/../scripts/lib/file_ops.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "atomic_write writes content" {
    run atomic_write "Line 1" "$TEST_FILE"
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_FILE")" = "Line 1" ]
}

@test "atomic_prepend prepends line" {
    atomic_write "Line 1" "$TEST_FILE"
    run atomic_prepend "Line 0" "$TEST_FILE"
    [ "$status" -eq 0 ]
    [ "$(head -n 1 "$TEST_FILE")" = "Line 0" ]
}

@test "atomic_replace_line replaces target line" {
    atomic_write "Line 1"$'\n'"Line 2" "$TEST_FILE"
    run atomic_replace_line 1 "Line Zero" "$TEST_FILE"
    [ "$status" -eq 0 ]
    [ "$(head -n 1 "$TEST_FILE")" = "Line Zero" ]
}

@test "atomic_delete_line removes target line" {
    atomic_write "Line 1"$'\n'"Line 2" "$TEST_FILE"
    run atomic_delete_line 1 "$TEST_FILE"
    [ "$status" -eq 0 ]
    [ "$(head -n 1 "$TEST_FILE")" = "Line 2" ]
}
