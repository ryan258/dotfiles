#!/usr/bin/env bats

# test_blog_factory_wrapper.sh - Compatibility wrapper coverage for extracted Blog Factory.

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    setup_test_environment
    export DOTFILES_DIR="$TEST_DIR/dotfiles"
    export PROJECTS_DIR="$TEST_DIR/Projects"
    export BLOG_FACTORY_HOME="$PROJECTS_DIR/blog-factory"

    mkdir -p "$DOTFILES_DIR/scripts/lib" "$PROJECTS_DIR"
    cp "$BATS_TEST_DIRNAME/../scripts/blog.sh" "$DOTFILES_DIR/scripts/blog.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/blog_recent_content.sh" "$DOTFILES_DIR/scripts/blog_recent_content.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$DOTFILES_DIR/scripts/lib/config.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/common.sh" "$DOTFILES_DIR/scripts/lib/common.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/file_ops.sh" "$DOTFILES_DIR/scripts/lib/file_ops.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/wrapper_common.sh" "$DOTFILES_DIR/scripts/lib/wrapper_common.sh"
    chmod +x "$DOTFILES_DIR/scripts/blog.sh" "$DOTFILES_DIR/scripts/blog_recent_content.sh"
}

@test "blog wrappers in source tree retain executable bit" {
    [ -x "$BATS_TEST_DIRNAME/../scripts/blog.sh" ]
    [ -x "$BATS_TEST_DIRNAME/../scripts/blog_recent_content.sh" ]
}

teardown() {
    teardown_test_environment
}

run_blog_wrapper() {
    env \
        HOME="$TEST_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        BLOG_FACTORY_HOME="$BLOG_FACTORY_HOME" \
        "$DOTFILES_DIR/scripts/blog.sh" "$@"
}

run_blog_recent_wrapper() {
    env \
        HOME="$TEST_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        BLOG_FACTORY_HOME="$BLOG_FACTORY_HOME" \
        "$DOTFILES_DIR/scripts/blog_recent_content.sh" "$@"
}

@test "blog wrapper delegates to sibling repo implementation" {
    mkdir -p "$BLOG_FACTORY_HOME/scripts"
    cat > "$BLOG_FACTORY_HOME/scripts/blog.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "blog helper: $*"
SH
    chmod +x "$BLOG_FACTORY_HOME/scripts/blog.sh"

    run run_blog_wrapper status --verbose

    [ "$status" -eq 0 ]
    [[ "$output" == "blog helper: status --verbose" ]]
}

@test "blog wrapper reports missing sibling repo for direct commands" {
    run run_blog_wrapper status

    [ "$status" -eq 3 ]
    [[ "$output" == *"Blog Factory is unavailable"* ]]
    [[ "$output" == *"$BLOG_FACTORY_HOME"* ]]
    [[ "$output" != *"Traceback"* ]]
}

@test "blog wrapper help reports missing sibling repo without failing" {
    run run_blog_wrapper --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Blog Factory is unavailable"* ]]
    [[ "$output" == *"$BLOG_FACTORY_HOME"* ]]
    [[ "$output" != *"Traceback"* ]]
}

@test "blog wrapper daily hook suppresses missing sibling setup details" {
    run env \
        HOME="$TEST_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        BLOG_FACTORY_HOME="$BLOG_FACTORY_HOME" \
        BLOG_FACTORY_DAILY_HOOK=true \
        "$DOTFILES_DIR/scripts/blog.sh" status

    [ "$status" -eq 3 ]
    [ "$output" = "" ]
}

@test "blog recent wrapper delegates to sibling repo implementation" {
    mkdir -p "$BLOG_FACTORY_HOME/scripts"
    cat > "$BLOG_FACTORY_HOME/scripts/blog_recent_content.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "blog recent helper: $*"
SH
    chmod +x "$BLOG_FACTORY_HOME/scripts/blog_recent_content.sh"

    run run_blog_recent_wrapper 3

    [ "$status" -eq 0 ]
    [[ "$output" == "blog recent helper: 3" ]]
}

@test "blog recent wrapper reports missing sibling repo for direct commands" {
    run run_blog_recent_wrapper 3

    [ "$status" -eq 3 ]
    [[ "$output" == *"Blog Factory recent-content helper is unavailable"* ]]
    [[ "$output" == *"$BLOG_FACTORY_HOME"* ]]
    [[ "$output" != *"Traceback"* ]]
}

@test "blog recent wrapper daily hook suppresses missing sibling setup details" {
    run env \
        HOME="$TEST_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        BLOG_FACTORY_HOME="$BLOG_FACTORY_HOME" \
        BLOG_FACTORY_DAILY_HOOK=true \
        "$DOTFILES_DIR/scripts/blog_recent_content.sh" 3

    [ "$status" -eq 3 ]
    [ "$output" = "" ]
}

@test "blog recent wrapper help reports missing sibling repo without failing" {
    run run_blog_recent_wrapper --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Blog Factory recent-content helper is unavailable"* ]]
    [[ "$output" == *"$BLOG_FACTORY_HOME"* ]]
    [[ "$output" != *"Traceback"* ]]
}
