#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"

setup() {
    setup_test_environment
    export DOTFILES_DIR
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

teardown() {
    teardown_test_environment
}

@test "all executable scripts pass bash -n syntax checks" {
    while IFS= read -r script_path; do
        run bash -n "$script_path"
        if [ "$status" -ne 0 ]; then
            echo "syntax failure: $script_path"
            echo "$output"
            return 1
        fi
    done < <(find "$DOTFILES_DIR/scripts" -maxdepth 1 -type f -name "*.sh" | sort)
}

@test "all library scripts pass bash -n syntax checks" {
    while IFS= read -r script_path; do
        run bash -n "$script_path"
        if [ "$status" -ne 0 ]; then
            echo "syntax failure: $script_path"
            echo "$output"
            return 1
        fi
    done < <(find "$DOTFILES_DIR/scripts/lib" -maxdepth 1 -type f -name "*.sh" | sort)
}
