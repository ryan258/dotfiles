#!/usr/bin/env bats

# test_dhp_chain.sh - Bats coverage for dispatcher chaining.

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    export TEST_ROOT
    TEST_ROOT="$(mktemp -d)"
    export HOME="$TEST_ROOT/home"
    export DATA_DIR="$HOME/.config/dotfiles-data"
    export DOTFILES_DIR="$TEST_ROOT/dotfiles"
    mkdir -p "$DATA_DIR" "$DOTFILES_DIR/bin" "$DOTFILES_DIR/scripts/lib"

    cp "$BATS_TEST_DIRNAME/../bin/dhp-chain.sh" "$DOTFILES_DIR/bin/dhp-chain.sh"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-shared.sh" "$DOTFILES_DIR/bin/dhp-shared.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/common.sh" "$DOTFILES_DIR/scripts/lib/common.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$DOTFILES_DIR/scripts/lib/config.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/file_ops.sh" "$DOTFILES_DIR/scripts/lib/file_ops.sh"
    chmod +x "$DOTFILES_DIR/bin/dhp-chain.sh"

    cat > "$DOTFILES_DIR/bin/dhp-tech.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat >/dev/null
echo "mock tech stderr" >&2
exit 7
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-tech.sh"

    cat > "$DOTFILES_DIR/bin/dhp-copy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-copy.sh"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "dhp-chain preserves dispatcher stderr when a step fails" {
    run bash -c "HOME='$HOME' DOTFILES_DIR='$DOTFILES_DIR' DATA_DIR='$DATA_DIR' bash '$DOTFILES_DIR/bin/dhp-chain.sh' tech copy -- 'test payload' 2>&1"

    [ "$status" -ne 0 ]
    [[ "$output" == *"mock tech stderr"* ]]
    [[ "$output" == *"Step 1 (tech) failed."* ]]
}
