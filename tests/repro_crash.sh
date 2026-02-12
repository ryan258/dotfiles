#!/usr/bin/env bats

setup() {
    export TEST_HOME
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"
}

teardown() {
    rm -rf "$TEST_HOME"
}

@test "ai_suggest does not crash when meds file has DOSE entries only" {
    mkdir -p "$HOME/.config/dotfiles-data"
    echo "DOSE|2025-11-21 10:00|TestMed" > "$HOME/.config/dotfiles-data/medications.txt"

    run bash "$BATS_TEST_DIRNAME/../scripts/ai_suggest.sh"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Analyzing your current context" ]]
}
