#!/usr/bin/env bats

# test_spoon_budget_lib.sh - Bats coverage for spoon budget library.

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

@test "calculate_activity_cost was removed (dead code cleanup)" {
    # calculate_activity_cost was an unused stub and has been removed.
    # Verify the sourced library does not define the function.
    run type calculate_activity_cost
    [ "$status" -ne 0 ]
}

@test "predict_spoon_depletion ignores pre-reset spends" {
    local today=$(date +%Y-%m-%d)
    
    init_daily_spoons 10
    echo "SPEND|$today|08:00|2|Task 1|8" >> "$SPOON_LOG"
    echo "SPEND|$today|10:00|3|Task 2|5" >> "$SPOON_LOG"
    
    set_daily_spoons 5
    echo "SPEND|$today|12:00|1|Task 3|4" >> "$SPOON_LOG"
    echo "SPEND|$today|13:00|1|Task 4|3" >> "$SPOON_LOG"
    
    date_now() {
        echo "14:00"
    }
    export -f date_now
    
    run predict_spoon_depletion
    [ "$status" -eq 0 ]
    
    # Should predict correctly using only post-reset data (12:00 to 13:00)
    [[ "$output" =~ "by " ]]
}
