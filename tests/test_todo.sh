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

@test "todo add validates input" {
  run bash "$BATS_TEST_DIRNAME/../scripts/todo.sh" add ""
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage" ]]
}

@test "todo add creates a new task" {
  run bash "$BATS_TEST_DIRNAME/../scripts/todo.sh" add "Test task 1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Test task 1" ]]
  [ -f "$TEST_DATA_DIR/.config/dotfiles-data/todo.txt" ]
  [[ "$(cat "$TEST_DATA_DIR/.config/dotfiles-data/todo.txt")" =~ "Test task 1" ]]
}

@test "todo list shows tasks" {
  echo "$(date +%Y-%m-%d)|Task A" >> "$TEST_DATA_DIR/.config/dotfiles-data/todo.txt"
  echo "$(date +%Y-%m-%d)|Task B" >> "$TEST_DATA_DIR/.config/dotfiles-data/todo.txt"

  run bash "$BATS_TEST_DIRNAME/../scripts/todo.sh" list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Task A" ]]
  [[ "$output" =~ "Task B" ]]
}
