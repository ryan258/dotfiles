#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    source "$BATS_TEST_DIRNAME/../scripts/lib/config.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/common.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/spoon_budget.sh"
}

teardown() {
    teardown_test_environment
}

@test "init_daily_spoons sets budget" {
    init_daily_spoons 12
    assert_file_contains "$SPOON_LOG" "BUDGET|$(date +%Y-%m-%d)|12"
}

@test "init_daily_spoons fails if already set" {
    init_daily_spoons 12
    run init_daily_spoons 10
    [ "$status" -eq 1 ]
    [[ "$output" =~ "already initialized" ]]
}

@test "spend_spoons reduces budget" {
    init_daily_spoons 12
    spend_spoons 3 "Meeting"
    
    assert_file_contains "$SPOON_LOG" "SPEND|$(date +%Y-%m-%d)"
    assert_file_contains "$SPOON_LOG" "|9" # remaining
    
    run get_remaining_spoons
    [ "$output" = "9" ]
}

@test "spend_spoons allows negative (debt)" {
    init_daily_spoons 2
    run spend_spoons 3 "Hard work"
    
    assert_file_contains "$SPOON_LOG" "|-1"
    [[ "$output" =~ "spoon debt" ]]
}

@test "get_remaining_spoons returns updated value" {
    init_daily_spoons 10
    spend_spoons 2 "A"
    spend_spoons 3 "B"
    
    run get_remaining_spoons
    [ "$output" = "5" ]
}

@test "calculate_activity_cost returns defaults" {
    run calculate_activity_cost "meeting"
    [ "$output" = "2" ]
    
    run calculate_activity_cost "unknown"
    [ "$output" = "1" ]
}
