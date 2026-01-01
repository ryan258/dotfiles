#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    # Source the library
    source "$BATS_TEST_DIRNAME/../scripts/lib/context_capture.sh"
}

teardown() {
    teardown_test_environment
}

@test "capture_current_context creates context directory" {
    cd "$TEST_DIR"
    capture_current_context "test-ctx"
    
    [ -d "$DOTFILES_DATA_DIR/contexts/test-ctx" ]
    [ -f "$DOTFILES_DATA_DIR/contexts/test-ctx/timestamp.txt" ]
}

@test "capture_current_context captures directory" {
    cd "$TEST_DIR"
    capture_current_context "dir-ctx"
    
    run cat "$DOTFILES_DATA_DIR/contexts/dir-ctx/directory.txt"
    [ "$output" = "$TEST_DIR" ]
}

@test "list_contexts shows captured context" {
    capture_current_context "list-me"
    run list_contexts
    [[ "$output" =~ "list-me" ]]
}

@test "restore_context prints cd command" {
    cd "$TEST_DIR"
    capture_current_context "restore-me"
    
    # Simulate being somewhere else
    cd /tmp
    
    run restore_context "restore-me"
    [[ "$output" =~ "cd \"$TEST_DIR\"" ]]
}

@test "restore_context fails on invalid name" {
    run restore_context "non-existent"
    [ "$status" -eq 1 ]
}
