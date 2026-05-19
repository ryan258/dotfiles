#!/usr/bin/env bats

# test_observer_wrapper.sh - Compatibility wrapper coverage for extracted Observer.

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    setup_test_environment
    export DOTFILES_DIR="$TEST_DIR/dotfiles"
    export PROJECTS_DIR="$TEST_DIR/projects"

    mkdir -p "$DOTFILES_DIR/scripts/lib" "$PROJECTS_DIR"
    cp "$BATS_TEST_DIRNAME/../scripts/observer.sh" "$DOTFILES_DIR/scripts/observer.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$DOTFILES_DIR/scripts/lib/config.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/common.sh" "$DOTFILES_DIR/scripts/lib/common.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/file_ops.sh" "$DOTFILES_DIR/scripts/lib/file_ops.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/wrapper_common.sh" "$DOTFILES_DIR/scripts/lib/wrapper_common.sh"
    chmod +x "$DOTFILES_DIR/scripts/observer.sh"
}

@test "observer wrapper in source tree retains executable bit" {
    [ -x "$BATS_TEST_DIRNAME/../scripts/observer.sh" ]
}

teardown() {
    teardown_test_environment
}

run_observer_wrapper() {
    env \
        HOME="$TEST_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        "$DOTFILES_DIR/scripts/observer.sh" "$@"
}

@test "observer wrapper delegates to sibling repo implementation" {
    mkdir -p "$PROJECTS_DIR/obsidian-observer/scripts"
    cat > "$PROJECTS_DIR/obsidian-observer/scripts/observer.py" <<'PY'
import sys

print("observer helper:", " ".join(sys.argv[1:]))
PY

    run run_observer_wrapper graph candidates

    [ "$status" -eq 0 ]
    [[ "$output" == "observer helper: graph candidates" ]]
}

@test "observer wrapper reports missing sibling repo for direct commands" {
    run run_observer_wrapper digest 2026-05-19

    [ "$status" -eq 3 ]
    [[ "$output" == *"Obsidian observer is unavailable"* ]]
    [[ "$output" == *"$PROJECTS_DIR/obsidian-observer"* ]]
    [[ "$output" != *"Traceback"* ]]
}

@test "observer wrapper help reports missing sibling repo without failing" {
    run run_observer_wrapper --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Obsidian observer is unavailable"* ]]
    [[ "$output" == *"$PROJECTS_DIR/obsidian-observer"* ]]
    [[ "$output" != *"Traceback"* ]]
}

@test "observer daily hook degrades quietly when sibling repo is missing" {
    run env \
        HOME="$TEST_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        OBSERVER_DAILY_HOOK=true \
        "$DOTFILES_DIR/scripts/observer.sh" startday 2026-05-19

    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "observer daily hook can explain missing sibling repo in verbose mode" {
    run env \
        HOME="$TEST_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        OBSERVER_DAILY_HOOK=true \
        OBSERVER_WRAPPER_VERBOSE=true \
        "$DOTFILES_DIR/scripts/observer.sh" startday 2026-05-19

    [ "$status" -eq 0 ]
    [[ "$output" == *"Obsidian observer is unavailable"* ]]
    [[ "$output" == *"$PROJECTS_DIR/obsidian-observer"* ]]
}
