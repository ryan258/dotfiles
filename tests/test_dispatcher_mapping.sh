#!/usr/bin/env bats

# test_dispatcher_mapping.sh - Bats coverage for dispatcher mapping.

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    export TEST_ROOT
    TEST_ROOT="$(mktemp -d)"
    export DOTFILES_DIR="$TEST_ROOT/dotfiles"
    mkdir -p "$DOTFILES_DIR/bin" "$DOTFILES_DIR/config"

    cp "$BATS_TEST_DIRNAME/../bin/dhp-shared.sh" "$DOTFILES_DIR/bin/dhp-shared.sh"
    cp "$BATS_TEST_DIRNAME/../config/dhp-dispatchers.tsv" "$DOTFILES_DIR/config/dhp-dispatchers.tsv"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$DOTFILES_DIR/bin/dhp-tech.sh"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$DOTFILES_DIR/bin/dhp-project.sh"
    chmod +x "$DOTFILES_DIR/bin/dhp-tech.sh" "$DOTFILES_DIR/bin/dhp-project.sh"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "dhp_dispatcher_script_name resolves aliases and canonical names" {
    run bash -c "source '$DOTFILES_DIR/bin/dhp-shared.sh'; dhp_dispatcher_script_name tech; dhp_dispatcher_script_name dhp-content; dhp_dispatcher_script_name dhp-copy.sh; dhp_dispatcher_script_name aicopy; dhp_dispatcher_script_name coach; dhp_dispatcher_script_name ai-project"

    [ "$status" -eq 0 ]
    lines="$(printf '%s\n' "$output")"
    [[ "$lines" == *"dhp-tech.sh"* ]]
    [[ "$lines" == *"dhp-content.sh"* ]]
    [[ "$lines" == *"dhp-copy.sh"* ]]
    [[ "$lines" == *"dhp-coach.sh"* ]]
    [[ "$lines" == *"dhp-project.sh"* ]]
}

@test "dispatcher registry exposes metadata and prompt paths" {
    run bash -c "DOTFILES_DIR='$DOTFILES_DIR'; source '$DOTFILES_DIR/bin/dhp-shared.sh'; dhp_registry_field tech display_name; dhp_registry_field tech prompt_file"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Technical Analysis"* ]]
    [[ "$output" == *"bin/prompts/tech.md"* ]]
}

@test "dhp_dispatcher_script_name rejects unknown dispatcher and list helper is stable" {
    run bash -c "source '$DOTFILES_DIR/bin/dhp-shared.sh'; dhp_dispatcher_script_name nope"

    [ "$status" -ne 0 ]

    run bash -c "source '$DOTFILES_DIR/bin/dhp-shared.sh'; dhp_dispatcher_script_name dhp"
    [ "$status" -ne 0 ]

    run bash -c "source '$DOTFILES_DIR/bin/dhp-shared.sh'; dhp_available_dispatchers"
    [ "$status" -eq 0 ]
    [[ "$output" == *"tech"* ]]
    [[ "$output" == *"copy"* ]]
    [[ "$output" == *"coach"* ]]
    [[ "$output" == *"chain"* ]]
    [[ "$output" == *"project"* ]]
    [[ "$output" == *"memory"* ]]
    [[ "$output" == *"memory-search"* ]]
}

@test "dhp_resolve_dispatcher_command centralizes command lookup" {
    run bash -c "DOTFILES_DIR='$DOTFILES_DIR'; source '$DOTFILES_DIR/bin/dhp-shared.sh'; dhp_resolve_dispatcher_command tech '$DOTFILES_DIR'; dhp_resolve_dispatcher_command project '$DOTFILES_DIR'"

    [ "$status" -eq 0 ]
    lines="$(printf '%s\n' "$output")"
    [[ "$lines" == *"$DOTFILES_DIR/bin/dhp-tech.sh"* ]]
    [[ "$lines" == *"$DOTFILES_DIR/bin/dhp-project.sh"* ]]
}
