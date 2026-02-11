#!/usr/bin/env bats

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    export TEST_ROOT
    TEST_ROOT="$(mktemp -d)"
    export HOME="$TEST_ROOT/home"
    export DATA_DIR="$HOME/.config/dotfiles-data"
    export DOTFILES_DIR="$TEST_ROOT/dotfiles"
    mkdir -p "$DATA_DIR" "$DOTFILES_DIR/bin" "$DOTFILES_DIR/scripts/lib"

    cp "$BATS_TEST_DIRNAME/../bin/dhp-shared.sh" "$DOTFILES_DIR/bin/dhp-shared.sh"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-tech.sh" "$DOTFILES_DIR/bin/dhp-tech.sh"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-content.sh" "$DOTFILES_DIR/bin/dhp-content.sh"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-lib.sh" "$DOTFILES_DIR/bin/dhp-lib.sh"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-utils.sh" "$DOTFILES_DIR/bin/dhp-utils.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$DOTFILES_DIR/scripts/lib/config.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/common.sh" "$DOTFILES_DIR/scripts/lib/common.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/file_ops.sh" "$DOTFILES_DIR/scripts/lib/file_ops.sh"
    chmod +x "$DOTFILES_DIR/bin/dhp-tech.sh" "$DOTFILES_DIR/bin/dhp-content.sh"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "dhp-shared based dispatcher rejects unknown flag" {
    run bash -c "HOME='$HOME' DOTFILES_DIR='$DOTFILES_DIR' DATA_DIR='$DATA_DIR' bash '$DOTFILES_DIR/bin/dhp-tech.sh' --bogus-flag 500 'Fix parser issue' 2>&1"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown flag: --bogus-flag"* ]]
}

@test "dhp-content custom parser rejects unknown flag" {
    run bash -c "HOME='$HOME' DOTFILES_DIR='$DOTFILES_DIR' DATA_DIR='$DATA_DIR' bash '$DOTFILES_DIR/bin/dhp-content.sh' --bogus-flag 320 'Guide to energy-first planning' 2>&1"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown flag: --bogus-flag"* ]]
}
