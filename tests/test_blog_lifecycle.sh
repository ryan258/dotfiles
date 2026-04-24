#!/usr/bin/env bats

# test_blog_lifecycle.sh - Bats coverage for blog lifecycle helpers.

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    setup_test_environment

    export BLOG_DIR="$TEST_DIR/blog"
    mkdir -p "$BLOG_DIR"
    touch "$DOTFILES_DATA_DIR/journal.txt"

    git -C "$BLOG_DIR" init >/dev/null
    git -C "$BLOG_DIR" config user.name "Test User"
    git -C "$BLOG_DIR" config user.email "test@example.com"

    cat > "$BLOG_DIR/post.md" <<'EOF'
hello
EOF
    git -C "$BLOG_DIR" add post.md
    git -C "$BLOG_DIR" commit -m "Initial post" >/dev/null
    git -C "$BLOG_DIR" tag -a v0.1.0 -m "Version v0.1.0" >/dev/null
}

teardown() {
    teardown_test_environment
}

@test "blog version history preserves the caller working directory" {
    run env \
        BLOG_DIR="$BLOG_DIR" \
        DATA_DIR="$DOTFILES_DATA_DIR" \
        JOURNAL_FILE="$DOTFILES_DATA_DIR/journal.txt" \
        bash -c 'start_dir=$PWD; source "$1"; source "$2"; blog_version history >/dev/null; printf "%s|%s" "$start_dir" "$PWD"' _ "$BATS_TEST_DIRNAME/../scripts/lib/common.sh" "$BATS_TEST_DIRNAME/../scripts/lib/blog_lifecycle.sh"

    [ "$status" -eq 0 ]
    [ "$output" = "$(pwd)|$(pwd)" ]
}
