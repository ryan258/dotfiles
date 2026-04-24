#!/usr/bin/env bats

# test_dispatcher_unknown_flags.sh - Bats coverage for dispatcher unknown flags.

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    export TEST_ROOT
    TEST_ROOT="$(mktemp -d)"
    export HOME="$TEST_ROOT/home"
    export DATA_DIR="$HOME/.config/dotfiles-data"
    export DOTFILES_DIR="$TEST_ROOT/dotfiles"
    export PATH="$TEST_ROOT/mock-bin:$PATH"
    mkdir -p "$DATA_DIR" "$DOTFILES_DIR/bin" "$DOTFILES_DIR/scripts/lib" "$TEST_ROOT/mock-bin"

    cp "$BATS_TEST_DIRNAME/../bin/dhp-shared.sh" "$DOTFILES_DIR/bin/dhp-shared.sh"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-tech.sh" "$DOTFILES_DIR/bin/dhp-tech.sh"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-copy.sh" "$DOTFILES_DIR/bin/dhp-copy.sh"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-content.sh" "$DOTFILES_DIR/bin/dhp-content.sh"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-lib.sh" "$DOTFILES_DIR/bin/dhp-lib.sh"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-utils.sh" "$DOTFILES_DIR/bin/dhp-utils.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$DOTFILES_DIR/scripts/lib/config.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/common.sh" "$DOTFILES_DIR/scripts/lib/common.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/file_ops.sh" "$DOTFILES_DIR/scripts/lib/file_ops.sh"
    chmod +x "$DOTFILES_DIR/bin/dhp-tech.sh" "$DOTFILES_DIR/bin/dhp-copy.sh" "$DOTFILES_DIR/bin/dhp-content.sh"

    cat > "$TEST_ROOT/mock-bin/uv" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$DATA_DIR/mock_uv_args.txt"
cat >/dev/null
printf 'mock swarm output\n'
EOF
    chmod +x "$TEST_ROOT/mock-bin/uv"
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

@test "dhp-copy shared parser rejects unknown flag" {
    run bash -c "HOME='$HOME' DOTFILES_DIR='$DOTFILES_DIR' DATA_DIR='$DATA_DIR' bash '$DOTFILES_DIR/bin/dhp-copy.sh' --bogus-flag 280 'Write launch copy' 2>&1"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown flag: --bogus-flag"* ]]
}

@test "dhp-content forwards shared flags after custom parsing" {
    run bash -c "PATH='$PATH' HOME='$HOME' DOTFILES_DIR='$DOTFILES_DIR' DATA_DIR='$DATA_DIR' OPENROUTER_API_KEY='test-key' DHP_CONTENT_OUTPUT_DIR='$DATA_DIR/content-output' bash '$DOTFILES_DIR/bin/dhp-content.sh' --temperature 0.5 'Guide to energy-first planning' 2>&1"

    [ "$status" -eq 0 ]
    run cat "$DATA_DIR/mock_uv_args.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--temperature 0.5"* ]]
}

@test "dhp-shared rejects out-of-range temperature values" {
    run bash -c "HOME='$HOME' DOTFILES_DIR='$DOTFILES_DIR' DATA_DIR='$DATA_DIR' bash '$DOTFILES_DIR/bin/dhp-tech.sh' --temperature 2.5 'Fix parser issue' 2>&1"

    [ "$status" -ne 0 ]
    [[ "$output" == *"between 0.0 and 2.0"* ]]
}

@test "dhp-shared surfaces swarm failures instead of exiting before its error branch" {
    cat > "$TEST_ROOT/mock-bin/uv" <<'EOF'
#!/usr/bin/env bash
echo "mock swarm stderr" >&2
cat >/dev/null
printf 'partial swarm output\n'
exit 9
EOF
    chmod +x "$TEST_ROOT/mock-bin/uv"

    run bash -c "PATH='$PATH' HOME='$HOME' DOTFILES_DIR='$DOTFILES_DIR' DATA_DIR='$DATA_DIR' OPENROUTER_API_KEY='test-key' DHP_TECH_OUTPUT_DIR='$DATA_DIR/output' bash '$DOTFILES_DIR/bin/dhp-tech.sh' 'Fix parser issue' 2>&1"

    [ "$status" -ne 0 ]
    [[ "$output" == *"partial swarm output"* ]]
    [[ "$output" == *"mock swarm stderr"* ]]
    [[ "$output" == *"FAILED: Swarm orchestration encountered an error"* ]]
}
