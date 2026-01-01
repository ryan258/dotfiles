#!/bin/bash

# tests/helpers/test_helpers.sh
# Shared utilities for BATS tests

setup_test_environment() {
    # Create a temporary directory for test data
    export TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR"
    export DOTFILES_DATA_DIR="$TEST_DIR/.config/dotfiles-data"
    
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
