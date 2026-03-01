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

@test "todo add strips pipe delimiters to keep records parseable" {
  run bash "$BATS_TEST_DIRNAME/../scripts/todo.sh" add "alpha|beta"
  [ "$status" -eq 0 ]

  raw_record="$(cat "$TEST_DATA_DIR/.config/dotfiles-data/todo.txt")"
  [[ "$raw_record" == *"alpha beta"* ]]
  [[ "$raw_record" != *"\\|"* ]]

  run bash "$BATS_TEST_DIRNAME/../scripts/todo.sh" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"alpha beta"* ]]
}

@test "todo list shows tasks" {
  echo "$(date +%Y-%m-%d)|Task A" >> "$TEST_DATA_DIR/.config/dotfiles-data/todo.txt"
  echo "$(date +%Y-%m-%d)|Task B" >> "$TEST_DATA_DIR/.config/dotfiles-data/todo.txt"

  run bash "$BATS_TEST_DIRNAME/../scripts/todo.sh" list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Task A" ]]
  [[ "$output" =~ "Task B" ]]
}

@test "todo to-idea moves task to idea list" {
  echo "$(date +%Y-%m-%d)|Task to idea" >> "$TEST_DATA_DIR/.config/dotfiles-data/todo.txt"
  touch "$TEST_DATA_DIR/.config/dotfiles-data/ideas.txt"

  run bash "$BATS_TEST_DIRNAME/../scripts/todo.sh" to-idea 1
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Moved task 1 to ideas list" ]]

  run bash "$BATS_TEST_DIRNAME/../scripts/idea.sh" list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Task to idea" ]]

  run bash "$BATS_TEST_DIRNAME/../scripts/todo.sh" list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No tasks found" ]]
}

@test "todo to-idea sanitizes legacy pipes" {
  echo "$(date +%Y-%m-%d)|Legacy task|with|pipes" >> "$TEST_DATA_DIR/.config/dotfiles-data/todo.txt"
  touch "$TEST_DATA_DIR/.config/dotfiles-data/ideas.txt"

  run bash "$BATS_TEST_DIRNAME/../scripts/todo.sh" to-idea 1
  [ "$status" -eq 0 ]

  run bash "$BATS_TEST_DIRNAME/../scripts/idea.sh" list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Legacy task with pipes" ]]
}

@test "todo to-idea requires an argument" {
  run bash "$BATS_TEST_DIRNAME/../scripts/todo.sh" to-idea
  [ "$status" -eq 2 ]
  [[ "$output" =~ "Usage:" ]]
}

@test "todo to-idea validates numeric input" {
  run bash "$BATS_TEST_DIRNAME/../scripts/todo.sh" to-idea "abc"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Invalid task number" ]]
}

@test "todo to-idea handles out of range" {
  touch "$TEST_DATA_DIR/.config/dotfiles-data/todo.txt"
  run bash "$BATS_TEST_DIRNAME/../scripts/todo.sh" to-idea 999
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Task 999 not found" ]]
}
