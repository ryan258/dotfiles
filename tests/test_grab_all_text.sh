#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment

    export DOTFILES_DIR
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    mkdir -p "$TEST_DIR/workspace"
}

teardown() {
    teardown_test_environment
}

@test "grab_all_text.sh skips gitignored files and copies text to clipboard" {
    mkdir -p "$TEST_DIR/fake-bin"

    cat > "$TEST_DIR/fake-bin/pbcopy" <<EOF
#!/usr/bin/env bash
cat > "$TEST_DIR/pbcopy_capture.txt"
EOF
    chmod +x "$TEST_DIR/fake-bin/pbcopy"

    cat > "$TEST_DIR/workspace/visible.txt" <<'EOF'
visible line
EOF
    cat > "$TEST_DIR/workspace/ignored.txt" <<'EOF'
secret line
EOF
    cat > "$TEST_DIR/workspace/.gitignore" <<'EOF'
ignored.txt
EOF
    cat > "$TEST_DIR/workspace/all_text_contents.txt" <<'EOF'
legacy output
EOF

    run env HOME="$HOME" PATH="$TEST_DIR/fake-bin:/usr/bin:/bin:/usr/sbin:/sbin" /bin/bash -c "
        cd '$TEST_DIR/workspace' &&
        git init >/dev/null 2>&1 &&
        '$DOTFILES_DIR/scripts/grab_all_text.sh'
    "

    [ "$status" -eq 0 ]
    [[ "$output" == *"Copied readable non-ignored text from 2 file(s) to the clipboard."* ]]
    assert_file_contains "$TEST_DIR/pbcopy_capture.txt" "visible line"
    assert_file_contains "$TEST_DIR/pbcopy_capture.txt" "ignored.txt"
    assert_file_not_contains "$TEST_DIR/pbcopy_capture.txt" "secret line"
    assert_file_not_contains "$TEST_DIR/pbcopy_capture.txt" "legacy output"
}
