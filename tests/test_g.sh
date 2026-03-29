#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    # Alias for backward compatibility with test assertions
    export TEST_DATA_DIR="$TEST_DIR"
}

teardown() {
    teardown_test_environment
}

@test "g.sh reports missing bookmarks file" {
    run bash -c "$BATS_TEST_DIRNAME/../scripts/g.sh missing-bookmark 2>&1"

    [ "$status" -eq 1 ]
    [[ "$output" =~ "No bookmarks saved" ]]
}

@test "g.sh suggest supports legacy colon logs and keeps paths with spaces intact" {
    local projects_dir="$HOME/Projects"
    local spaced_dir="$projects_dir/the merge/promptchaining-lab"
    local dotfiles_dir="$HOME/dotfiles"

    mkdir -p "$spaced_dir" "$dotfiles_dir"

    cat > "$DATA_DIR/dir_usage.log" <<EOF
1774550000:$spaced_dir
1774550600:$spaced_dir
1774551200:$dotfiles_dir
malformed line
EOF

    run env HOME="$HOME" DATA_DIR="$DATA_DIR" bash -c "$BATS_TEST_DIRNAME/../scripts/g.sh suggest"

    [ "$status" -eq 0 ]
    first_line="$(printf '%s\n' "$output" | head -n 1)"
    [[ "$first_line" == *"$spaced_dir"* ]]
    [[ "$output" == *"$dotfiles_dir"* ]]
    [[ "$output" != *"malformed line"* ]]
}
