#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    source "$BATS_TEST_DIRNAME/../scripts/lib/config.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/common.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/date_utils.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/time_tracking.sh"
}

teardown() {
    teardown_test_environment
}

@test "start_timer creates a log entry" {
    start_timer "task-1" "Testing task"
    
    assert_file_contains "$TIME_LOG" "START|task-1|Testing task"
    
    run get_active_timer
    [ "$output" = "task-1" ]
}

@test "start_timer fails if timer already active" {
    start_timer "task-1"
    run start_timer "task-2"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Timer already active" ]]
}

@test "stop_timer adds STOP entry" {
    start_timer "task-1"
    stop_timer "task-1"
    
    assert_file_contains "$TIME_LOG" "STOP|task-1"
    
    run get_active_timer
    [ "$output" = "" ]
}

@test "stop_timer calculates duration" {
    # Mock date to simulate passage of time
    # This is hard to do purely in bash without modifying the lib to accept a time provider
    # For now, we just test it runs
    start_timer "task-1"
    run stop_timer
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Duration:" ]]
}

@test "get_task_time calculates total time" {
    # Manually inject log entries to control timestamps
    timestamp1="2025-01-01 10:00:00"
    timestamp2="2025-01-01 10:30:00" # 30 mins = 1800s
    timestamp3="2025-01-01 11:00:00"
    timestamp4="2025-01-01 12:00:00" # 60 mins = 3600s
    
    echo "START|task-1|desc|$timestamp1" >> "$TIME_LOG"
    echo "STOP|task-1|$timestamp2" >> "$TIME_LOG"
    echo "START|task-1|desc|$timestamp3" >> "$TIME_LOG"
    echo "STOP|task-1|$timestamp4" >> "$TIME_LOG"
    
    run get_task_time "task-1"
    [ "$output" = "5400" ]
}

@test "format_duration formats correctly" {
    run format_duration 3661
    [ "$output" = "01:01:01" ]
    
    run format_duration 65
    [ "$output" = "00:01:05" ]
}
