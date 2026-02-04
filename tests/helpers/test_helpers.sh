#!/usr/bin/env bash

# tests/helpers/test_helpers.sh
# Shared utilities for BATS tests

setup_test_environment() {
    # Create a temporary directory for test data
    local raw_dir
    raw_dir=$(mktemp -d)
    local real_dir="$raw_dir"
    if command -v python3 >/dev/null 2>&1; then
        real_dir=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$raw_dir")
    elif command -v realpath >/dev/null 2>&1; then
        real_dir=$(realpath "$raw_dir")
    else
        real_dir=$(cd "$raw_dir" && pwd -P)
    fi

    export TEST_DIR="$real_dir"
    export HOME="$real_dir"
    export DOTFILES_DATA_DIR="$real_dir/.config/dotfiles-data"
    
    # Create the data structure
    mkdir -p "$DOTFILES_DATA_DIR"
    
    # Override the generic data directory variable if it exists in scripts
    export DATA_DIR="$DOTFILES_DATA_DIR"
}

teardown_test_environment() {
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}
