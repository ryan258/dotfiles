#!/usr/bin/env bats

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    setup_test_environment
    export DOTFILES_DIR="$TEST_DIR/dotfiles"
    mkdir -p "$DOTFILES_DIR/scripts/lib" "$DATA_DIR"

    cp "$BATS_TEST_DIRNAME/../scripts/repo_tracker.sh" "$DOTFILES_DIR/scripts/repo_tracker.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/common.sh" "$DOTFILES_DIR/scripts/lib/common.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$DOTFILES_DIR/scripts/lib/config.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/date_utils.sh" "$DOTFILES_DIR/scripts/lib/date_utils.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/github_ops.sh" "$DOTFILES_DIR/scripts/lib/github_ops.sh"
    chmod +x "$DOTFILES_DIR/scripts/repo_tracker.sh"
}

teardown() {
    teardown_test_environment
}

@test "repo_tracker.sh deactivates, lists, and reactivates repos" {
    run env DOTFILES_DIR="$DOTFILES_DIR" HOME="$HOME" bash "$DOTFILES_DIR/scripts/repo_tracker.sh" deactivate dotfiles "good place"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Deactivated repo: dotfiles"* ]]

    run env DOTFILES_DIR="$DOTFILES_DIR" HOME="$HOME" bash "$DOTFILES_DIR/scripts/repo_tracker.sh" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"Inactive repos:"* ]]
    [[ "$output" == *"dotfiles (inactive"* ]]
    [[ "$output" == *"good place"* ]]

    run env DOTFILES_DIR="$DOTFILES_DIR" HOME="$HOME" bash "$DOTFILES_DIR/scripts/repo_tracker.sh" names
    [ "$status" -eq 0 ]
    [ "$output" = "dotfiles" ]

    run env DOTFILES_DIR="$DOTFILES_DIR" HOME="$HOME" bash "$DOTFILES_DIR/scripts/repo_tracker.sh" reactivate dotfiles
    [ "$status" -eq 0 ]
    [[ "$output" == *"Reactivated repo: dotfiles"* ]]

    run env DOTFILES_DIR="$DOTFILES_DIR" HOME="$HOME" bash "$DOTFILES_DIR/scripts/repo_tracker.sh" list
    [ "$status" -eq 0 ]
    [ "$output" = "(No inactive repos)" ]
}

@test "repo_tracker.sh reports already-active repos on no-op reactivate" {
    run env DOTFILES_DIR="$DOTFILES_DIR" HOME="$HOME" bash "$DOTFILES_DIR/scripts/repo_tracker.sh" reactivate dotfiles

    [ "$status" -eq 0 ]
    [ "$output" = "Repo already active: dotfiles" ]
}
