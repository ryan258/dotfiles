#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"
load "$BATS_TEST_DIRNAME/helpers/mock_ai.sh"

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

@test "setup_test_environment creates temporary directory" {
    [ -d "$TEST_DIR" ]
    [ -d "$DOTFILES_DATA_DIR" ]
}

@test "assert_file_contains works correctly" {
    echo "Hello World" > "$TEST_DIR/testfile.txt"
    assert_file_contains "$TEST_DIR/testfile.txt" "Hello"
}

@test "assert_file_not_contains works correctly" {
    echo "Hello World" > "$TEST_DIR/testfile.txt"
    assert_file_not_contains "$TEST_DIR/testfile.txt" "Goodbye"
}

@test "mock_ai_response works" {
    mock_ai_response "I am a helpful AI"
    run dhp-strategy "some input"
    [ "$output" = "I am a helpful AI" ]
}
