#!/usr/bin/env bats

# Set up test fixture directory
setup() {
    export TEST_DATA_DIR="$(mktemp -d)"
    export HOME="$TEST_DATA_DIR"  # Override HOME for tests
    mkdir -p "$TEST_DATA_DIR/.config/dotfiles-data"
}

# Clean up after tests
teardown() {
    rm -rf "$TEST_DATA_DIR"
}

@test "todo add validates input" {
  run bash ../scripts/todo.sh add ""
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage" ]]
}

@test "todo add creates a new task" {
  run bash ../scripts/todo.sh add "Test task 1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Added: Test task 1" ]]
  [ -f "$TEST_DATA_DIR/.config/dotfiles-data/todo.txt" ]
  [[ "$(cat "$TEST_DATA_DIR/.config/dotfiles-data/todo.txt")" =~ "Test task 1" ]]
}

@test "todo list shows tasks" {
  echo "$(date +%Y-%m-%d)|Task A" >> "$TEST_DATA_DIR/.config/dotfiles-data/todo.txt"
  echo "$(date +%Y-%m-%d)|Task B" >> "$TEST_DATA_DIR/.config/dotfiles-data/todo.txt"

  run bash ../scripts/todo.sh list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Task A" ]]
  [[ "$output" =~ "Task B" ]]
}