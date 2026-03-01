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

@test "idea add validates input" {
  run bash "$BATS_TEST_DIRNAME/../scripts/idea.sh" add ""
  [ "$status" -eq 2 ]
  [[ "$output" =~ "Usage" ]]
}

@test "idea add creates a new idea" {
  run bash "$BATS_TEST_DIRNAME/../scripts/idea.sh" add "Learn rust"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Learn rust" ]]
  [ -f "$TEST_DATA_DIR/.config/dotfiles-data/ideas.txt" ]
  [[ "$(cat "$TEST_DATA_DIR/.config/dotfiles-data/ideas.txt")" =~ "Learn rust" ]]
}

@test "idea list shows ideas" {
  echo "$(date +%Y-%m-%d)|Idea A" >> "$TEST_DATA_DIR/.config/dotfiles-data/ideas.txt"
  echo "$(date +%Y-%m-%d)|Idea B" >> "$TEST_DATA_DIR/.config/dotfiles-data/ideas.txt"

  run bash "$BATS_TEST_DIRNAME/../scripts/idea.sh" list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Idea A" ]]
  [[ "$output" =~ "Idea B" ]]
}

@test "idea rm removes an idea" {
  echo "$(date +%Y-%m-%d)|Idea C" >> "$TEST_DATA_DIR/.config/dotfiles-data/ideas.txt"
  echo "$(date +%Y-%m-%d)|Idea D" >> "$TEST_DATA_DIR/.config/dotfiles-data/ideas.txt"

  run bash "$BATS_TEST_DIRNAME/../scripts/idea.sh" rm 1
  [ "$status" -eq 0 ]

  run bash "$BATS_TEST_DIRNAME/../scripts/idea.sh" list
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "Idea C" ]]
  [[ "$output" =~ "Idea D" ]]
}

@test "idea clear removes all ideas" {
  echo "$(date +%Y-%m-%d)|Idea E" >> "$TEST_DATA_DIR/.config/dotfiles-data/ideas.txt"
  echo "$(date +%Y-%m-%d)|Idea F" >> "$TEST_DATA_DIR/.config/dotfiles-data/ideas.txt"

  run bash "$BATS_TEST_DIRNAME/../scripts/idea.sh" clear
  [ "$status" -eq 0 ]

  run bash "$BATS_TEST_DIRNAME/../scripts/idea.sh" list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No ideas found" ]]
}

@test "idea to-todo moves idea to todo list" {
  echo "$(date +%Y-%m-%d)|Take over the world" >> "$TEST_DATA_DIR/.config/dotfiles-data/ideas.txt"
  touch "$TEST_DATA_DIR/.config/dotfiles-data/todo.txt"

  run bash "$BATS_TEST_DIRNAME/../scripts/idea.sh" to-todo 1
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Moved idea to actionable todo" ]]

  run bash "$BATS_TEST_DIRNAME/../scripts/todo.sh" list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Take over the world" ]]

  run bash "$BATS_TEST_DIRNAME/../scripts/idea.sh" list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No ideas found" ]]
}

@test "idea to-todo sanitizes legacy pipes" {
  echo "$(date +%Y-%m-%d)|Legacy idea|with|extra|pipes" >> "$TEST_DATA_DIR/.config/dotfiles-data/ideas.txt"
  touch "$TEST_DATA_DIR/.config/dotfiles-data/todo.txt"

  run bash "$BATS_TEST_DIRNAME/../scripts/idea.sh" to-todo 1
  [ "$status" -eq 0 ]

  run bash "$BATS_TEST_DIRNAME/../scripts/todo.sh" list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Legacy idea with extra pipes" ]]
}

@test "idea rm requires an argument" {
  run bash "$BATS_TEST_DIRNAME/../scripts/idea.sh" rm
  [ "$status" -eq 2 ]
  [[ "$output" =~ "Usage:" ]]
}

@test "idea to-todo requires an argument" {
  run bash "$BATS_TEST_DIRNAME/../scripts/idea.sh" to-todo
  [ "$status" -eq 2 ]
  [[ "$output" =~ "Usage:" ]]
}

@test "idea rm validates numeric input" {
  run bash "$BATS_TEST_DIRNAME/../scripts/idea.sh" rm "abc"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Invalid idea number" ]]
}

@test "idea rm handles out of range" {
  touch "$TEST_DATA_DIR/.config/dotfiles-data/ideas.txt"
  run bash "$BATS_TEST_DIRNAME/../scripts/idea.sh" rm 999
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Idea 999 not found" ]]
}
