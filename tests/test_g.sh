#!/usr/bin/env bats

setup() {
    export TEST_DATA_DIR="$(mktemp -d)"
    export HOME="$TEST_DATA_DIR"
    mkdir -p "$HOME/.config/dotfiles-data"
}

teardown() {
    rm -rf "$TEST_DATA_DIR"
}

@test "g.sh reports missing bookmarks file" {
    run bash -c "$BATS_TEST_DIRNAME/../scripts/g.sh missing-bookmark 2>&1"

    [ "$status" -eq 1 ]
    [[ "$output" =~ "No bookmarks saved" ]]
}
