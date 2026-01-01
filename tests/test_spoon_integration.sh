#!/usr/bin/env bats

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    setup_test_environment
    
    # Stage scripts
    mkdir -p "$TEST_DIR/scripts/lib"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/spoon_budget.sh" "$TEST_DIR/scripts/lib/"
    cp "$BATS_TEST_DIRNAME/../scripts/spoon_manager.sh" "$TEST_DIR/scripts/"
    cp "$BATS_TEST_DIRNAME/../scripts/todo.sh" "$TEST_DIR/scripts/"
    chmod +x "$TEST_DIR/scripts/"*.sh
    
    # Configure todo data
    mkdir -p "$DATA_DIR"
    echo "$(date +%Y-%m-%d)|Task 1: Testing spoons" > "$DATA_DIR/todo.txt"
    
    # Set override for DATA_DIR which scripts use
    export DATA_DIR="$DATA_DIR"
}

teardown() {
    teardown_test_environment
}

@test "spoon_manager.sh init sets daily budget" {
    run "$TEST_DIR/scripts/spoon_manager.sh" init 15
    [ "$status" -eq 0 ]
    assert_file_contains "$DATA_DIR/spoons.txt" "BUDGET|$(date +%Y-%m-%d)|15"
}

@test "spoon_manager.sh init fails with string input" {
    run "$TEST_DIR/scripts/spoon_manager.sh" init "twelve"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: Count must be a positive integer" ]]
}

@test "spoon_manager.sh check shows remaining" {
    "$TEST_DIR/scripts/spoon_manager.sh" init 10
    run "$TEST_DIR/scripts/spoon_manager.sh" check
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Remaining spoons: 10" ]]
}

@test "spoon_manager.sh spend decreases budget" {
    "$TEST_DIR/scripts/spoon_manager.sh" init 10
    run "$TEST_DIR/scripts/spoon_manager.sh" spend 2 "Coding"
    [ "$status" -eq 0 ]
    assert_file_contains "$DATA_DIR/spoons.txt" "SPEND|$(date +%Y-%m-%d)"
    assert_file_contains "$DATA_DIR/spoons.txt" "|2|Coding|8"
    
    run "$TEST_DIR/scripts/spoon_manager.sh" check
    [[ "$output" =~ "Remaining spoons: 8" ]]
}

@test "todo.sh spend integrates with spoon manager" {
    "$TEST_DIR/scripts/spoon_manager.sh" init 10
    run "$TEST_DIR/scripts/todo.sh" spend 1 3
    [ "$status" -eq 0 ]
    assert_file_contains "$DATA_DIR/spoons.txt" "|3|Task 1: Testing spoons|7"
}

@test "todo.sh spend fails if no budget init" {
    # No init called
    run "$TEST_DIR/scripts/todo.sh" spend 1 3
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No spoon budget initialized" ]]
}

@test "spoon_manager.sh cost returns standard values" {
    run "$TEST_DIR/scripts/spoon_manager.sh" cost "meeting"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Standard cost for 'meeting': 2" ]]
}

@test "spoon_manager.sh init twice fails" {
    run "$TEST_DIR/scripts/spoon_manager.sh" init 12
    [ "$status" -eq 0 ]
    
    run "$TEST_DIR/scripts/spoon_manager.sh" init 12
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Budget already initialized" ]]
}
