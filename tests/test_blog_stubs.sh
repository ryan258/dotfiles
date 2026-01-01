#!/usr/bin/env bats

setup() {
    export TEST_DATA_DIR="$(mktemp -d)"
    export HOME="$TEST_DATA_DIR"
    mkdir -p "$HOME/dotfiles/bin"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-utils.sh" "$HOME/dotfiles/bin/dhp-utils.sh"

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
