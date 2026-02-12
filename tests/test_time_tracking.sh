#!/usr/bin/env bats

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    setup_test_environment
    
    # Stage scripts in a temp directory to simulate real environment
    mkdir -p "$TEST_DIR/scripts/lib"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/common.sh" "$TEST_DIR/scripts/lib/"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$TEST_DIR/scripts/lib/"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/file_ops.sh" "$TEST_DIR/scripts/lib/"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/time_tracking.sh" "$TEST_DIR/scripts/lib/"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/date_utils.sh" "$TEST_DIR/scripts/lib/"
    cp "$BATS_TEST_DIRNAME/../scripts/time_tracker.sh" "$TEST_DIR/scripts/"
    cp "$BATS_TEST_DIRNAME/../scripts/todo.sh" "$TEST_DIR/scripts/"
    chmod +x "$TEST_DIR/scripts/"*.sh
    
    # Configure todo data
    mkdir -p "$DATA_DIR"
    echo "$(date +%Y-%m-%d)|Task 1: Testing time tracking" > "$DATA_DIR/todo.txt"
    echo "$(date +%Y-%m-%d)|Task 2: Another task" >> "$DATA_DIR/todo.txt"
    
    # Set override for DATA_DIR which scripts use
    export DATA_DIR="$DATA_DIR"
}

teardown() {
    teardown_test_environment
}

@test "time_tracker.sh start creates a timer" {
    run "$TEST_DIR/scripts/time_tracker.sh" start "1" "Task 1"
    [ "$status" -eq 0 ]
    assert_file_contains "$DATA_DIR/time_tracking.txt" "START|1|Task 1"
}

@test "time_tracker.sh stop ends a timer" {
    "$TEST_DIR/scripts/time_tracker.sh" start "1" "Task 1"
    sleep 1
    run "$TEST_DIR/scripts/time_tracker.sh" stop
    [ "$status" -eq 0 ]
    assert_file_contains "$DATA_DIR/time_tracking.txt" "STOP|1"
    [[ "$output" =~ "Duration:" ]]
}

@test "todo.sh start integrates with time tracking" {
    run "$TEST_DIR/scripts/todo.sh" start 1
    [ "$status" -eq 0 ]
    assert_file_contains "$DATA_DIR/time_tracking.txt" "START|1|Task 1: Testing time tracking"
}

@test "todo.sh stop integrates with time tracking" {
    "$TEST_DIR/scripts/todo.sh" start 1
    sleep 1
    run "$TEST_DIR/scripts/todo.sh" stop
    [ "$status" -eq 0 ]
    assert_file_contains "$DATA_DIR/time_tracking.txt" "STOP|1"
}

@test "todo.sh time shows duration" {
    # We need to manually inject a completed session to test check reliably without waiting
    # Or just start/stop
    "$TEST_DIR/scripts/todo.sh" start 1
    sleep 2
    "$TEST_DIR/scripts/todo.sh" stop
    
    run "$TEST_DIR/scripts/todo.sh" time 1
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Total time for task 1:" ]]
    # Should be at least 2 seconds, format 00:00:02
    [[ "$output" =~ "00:00:0" ]]
}

@test "todo.sh fails start if task not found" {
    run "$TEST_DIR/scripts/todo.sh" start 99
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: Task 99 not found" ]]
}
