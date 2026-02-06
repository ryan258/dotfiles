#!/usr/bin/env bats

setup() {
    export TEST_DATA_DIR="$(mktemp -d)"
    export HOME="$TEST_DATA_DIR"
    export DOTFILES_DIR="$HOME/dotfiles"
    mkdir -p "$DOTFILES_DIR/bin" "$DOTFILES_DIR/scripts/lib"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-utils.sh" "$DOTFILES_DIR/bin/dhp-utils.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/common.sh" "$DOTFILES_DIR/scripts/lib/common.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$DOTFILES_DIR/scripts/lib/config.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/file_ops.sh" "$DOTFILES_DIR/scripts/lib/file_ops.sh"

    export BLOG_DIR="$HOME/blog"
    mkdir -p "$BLOG_DIR/content/posts"
    echo "title: \"Test Post\"" > "$BLOG_DIR/content/posts/test.md"
}

teardown() {
    rm -rf "$TEST_DATA_DIR"
}

@test "blog stubs handles no stub files gracefully" {
    run bash "$BATS_TEST_DIRNAME/../scripts/blog.sh" stubs

    [ "$status" -eq 0 ]
    [[ "$output" =~ "No content stubs found" ]]
}
