#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment

    export DOTFILES_DIR
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

    mkdir -p "$DOTFILES_DATA_DIR"
    touch "$DOTFILES_DATA_DIR/todo.txt"
    touch "$DOTFILES_DATA_DIR/todo_done.txt"
    touch "$DOTFILES_DATA_DIR/journal.txt"
    touch "$DOTFILES_DATA_DIR/health.txt"
    touch "$DOTFILES_DATA_DIR/dir_bookmarks"
    touch "$DOTFILES_DATA_DIR/dir_history"
    touch "$DOTFILES_DATA_DIR/dir_usage.log"
    touch "$DOTFILES_DATA_DIR/system.log"
    touch "$DOTFILES_DATA_DIR/clipboard_history.txt"
    chmod 600 "$DOTFILES_DATA_DIR"/* || true
}

teardown() {
    teardown_test_environment
}

@test "focus.sh supports set/show/done flow" {
    run "$DOTFILES_DIR/scripts/focus.sh" set "Finish daily plan"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Focus set"* ]]

    run "$DOTFILES_DIR/scripts/focus.sh" show
    [ "$status" -eq 0 ]
    [[ "$output" == *"Finish daily plan"* ]]

    run "$DOTFILES_DIR/scripts/focus.sh" done
    [ "$status" -eq 0 ]
    [[ "$output" == *"Focus completed"* ]]
}

@test "status.sh runs non-interactively without crashing" {
    run "$DOTFILES_DIR/scripts/status.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"TODAY'S FOCUS"* ]]
    [[ "$output" == *"TASKS"* ]]
}

@test "backup_data.sh creates a local archive in configured backup dir" {
    echo "test task" > "$DOTFILES_DATA_DIR/todo.txt"
    export DOTFILES_BACKUP_DIR="$TEST_DIR/backups"

    run "$DOTFILES_DIR/scripts/backup_data.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Local backup created"* ]]

    run find "$DOTFILES_BACKUP_DIR" -type f -name "dotfiles-data-backup-*.tar.gz"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "dev_shortcuts.sh json subcommand fails clearly for missing file" {
    run "$DOTFILES_DIR/scripts/dev_shortcuts.sh" json "$TEST_DIR/missing.json"
    [ "$status" -eq 3 ]
    [[ "$output" == *"JSON file not found"* ]]
}

@test "schedule.sh returns invalid-args when called without time" {
    run "$DOTFILES_DIR/scripts/schedule.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Usage: schedule.sh"* ]]
}

@test "logs.sh rejects unknown command with invalid-args status" {
    run "$DOTFILES_DIR/scripts/logs.sh" invalid
    [ "$status" -eq 2 ]
    [[ "$output" == *"Unknown command"* ]]
}

@test "network_info.sh rejects unknown command with invalid-args status" {
    run "$DOTFILES_DIR/scripts/network_info.sh" invalid
    [ "$status" -eq 2 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "clipboard_manager.sh requires mode argument" {
    run "$DOTFILES_DIR/scripts/clipboard_manager.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "clipboard_manager.sh load returns file-not-found for unknown clip" {
    run "$DOTFILES_DIR/scripts/clipboard_manager.sh" load "missing-clip-name"
    [ "$status" -eq 3 ]
    [[ "$output" == *"not found"* ]]
}

@test "dump.sh completes safely when editor writes no content" {
    export EDITOR=true
    run "$DOTFILES_DIR/scripts/dump.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing saved"* ]]
}

@test "data_validate.sh help returns success" {
    run "$DOTFILES_DIR/scripts/data_validate.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}
