#!/usr/bin/env bats

# test_morphling_wrapper.sh - Bats coverage for morphling wrapper.

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    export TEST_ROOT
    TEST_ROOT="$(mktemp -d)"
    export DOTFILES_DIR="$TEST_ROOT/dotfiles"
    mkdir -p "$DOTFILES_DIR/bin" "$DOTFILES_DIR/ai-staff-hq/tools" "$TEST_ROOT/bin"

    cp "$BATS_TEST_DIRNAME/../bin/morphling.sh" "$DOTFILES_DIR/bin/morphling.sh"
    chmod +x "$DOTFILES_DIR/bin/morphling.sh"

    cat > "$DOTFILES_DIR/bin/dhp-morphling.sh" <<'EOF'
#!/usr/bin/env bash
printf 'swarm:%s\n' "$*"
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-morphling.sh"

    cat > "$TEST_ROOT/bin/uv" <<'EOF'
#!/usr/bin/env bash
printf 'uv:%s\n' "$*"
EOF
    chmod +x "$TEST_ROOT/bin/uv"

    cat > "$DOTFILES_DIR/ai-staff-hq/tools/activate.py" <<'EOF'
print("stub")
EOF

    export PATH="$TEST_ROOT/bin:$PATH"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "morphling help shows direct and swarm modes" {
    run bash -lc "DOTFILES_DIR='$DOTFILES_DIR' '$DOTFILES_DIR/bin/morphling.sh' --help"

    [ "$status" -eq 0 ]
    [[ "$output" == *"direct (default)"* ]]
    [[ "$output" == *"--swarm"* ]]
}

@test "morphling defaults to direct one-shot mode for plain text input" {
    run bash -lc "DOTFILES_DIR='$DOTFILES_DIR' '$DOTFILES_DIR/bin/morphling.sh' 'test prompt'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"uv:run --project $DOTFILES_DIR/ai-staff-hq python $DOTFILES_DIR/ai-staff-hq/tools/activate.py morphling -q test prompt"* ]]
}

@test "morphling delegates to swarm mode when requested" {
    run bash -lc "DOTFILES_DIR='$DOTFILES_DIR' '$DOTFILES_DIR/bin/morphling.sh' --swarm 'test prompt'"

    [ "$status" -eq 0 ]
    [[ "$output" == "swarm:test prompt" ]]
}
