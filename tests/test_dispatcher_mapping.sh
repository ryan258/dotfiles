#!/usr/bin/env bats

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    export TEST_ROOT
    TEST_ROOT="$(mktemp -d)"
    export DOTFILES_DIR="$TEST_ROOT/dotfiles"
    mkdir -p "$DOTFILES_DIR/bin"

    cp "$BATS_TEST_DIRNAME/../bin/dhp-shared.sh" "$DOTFILES_DIR/bin/dhp-shared.sh"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "dhp_dispatcher_script_name resolves aliases and canonical names" {
    run bash -c "source '$DOTFILES_DIR/bin/dhp-shared.sh'; dhp_dispatcher_script_name tech; dhp_dispatcher_script_name dhp-content; dhp_dispatcher_script_name dhp-copy.sh"

    [ "$status" -eq 0 ]
    lines="$(printf '%s\n' "$output")"
    [[ "$lines" == *"dhp-tech.sh"* ]]
    [[ "$lines" == *"dhp-content.sh"* ]]
    [[ "$lines" == *"dhp-copy.sh"* ]]
}

@test "dhp_dispatcher_script_name rejects unknown dispatcher and list helper is stable" {
    run bash -c "source '$DOTFILES_DIR/bin/dhp-shared.sh'; dhp_dispatcher_script_name nope"

    [ "$status" -ne 0 ]

    run bash -c "source '$DOTFILES_DIR/bin/dhp-shared.sh'; dhp_available_dispatchers"
    [ "$status" -eq 0 ]
    [[ "$output" == *"tech"* ]]
    [[ "$output" == *"copy"* ]]
}
