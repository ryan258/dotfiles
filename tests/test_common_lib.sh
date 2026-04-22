#!/usr/bin/env bats

# test_common_lib.sh - Bats coverage for common library.

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment

    # common.sh requires SYSTEM_LOG_FILE (or SYSTEM_LOG) at source time.
    # Set it to a path inside the test sandbox so logging works.
    export SYSTEM_LOG_FILE="$TEST_DIR/test_system.log"

    # Prevent config.sh from trying to source a real .env
    export ENV_FILE="$TEST_DIR/.env"
    touch "$ENV_FILE"

    # Point DOTFILES_DIR into the sandbox so config.sh path derivation stays safe
    export DOTFILES_DIR="$TEST_DIR"

    # Clear double-source guards so each test gets a fresh load
    unset _COMMON_SH_LOADED COMMON_SH_LOADED
    unset _DOTFILES_CONFIG_LOADED
    unset _FILE_OPS_LOADED
    unset _DOTFILES_ENV_FILE_LOADED

    # shellcheck disable=SC1090
    source "$BATS_TEST_DIRNAME/../scripts/lib/common.sh"
}

teardown() {
    teardown_test_environment
}

# =========================================================================
# sanitize_input
# =========================================================================

@test "sanitize_input strips pipe characters" {
    run sanitize_input "hello|world"
    [ "$status" -eq 0 ]
    [ "$output" = "hello world" ]
}

@test "sanitize_input removes control characters" {
    # Bash cannot embed literal null bytes in variables, so test other
    # control characters that tr -d '\000-\010\013\014\016-\037' strips.
    input=$'safe\x01\x02text'
    run sanitize_input "$input"
    [ "$status" -eq 0 ]
    [ "$output" = "safetext" ]
}

@test "sanitize_input preserves normal text" {
    run sanitize_input "Hello, world! 123"
    [ "$status" -eq 0 ]
    [ "$output" = "Hello, world! 123" ]
}

@test "sanitize_input handles empty string" {
    run sanitize_input ""
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "sanitize_input preserves tabs and newlines" {
    input=$'line1\tword\nline2'
    run sanitize_input "$input"
    [ "$status" -eq 0 ]
    [[ "$output" == *"line1"* ]]
    [[ "$output" == *"line2"* ]]
}

# =========================================================================
# validate_numeric
# =========================================================================

@test "validate_numeric accepts positive integers" {
    run validate_numeric "42" "count"
    [ "$status" -eq 0 ]
}

@test "validate_numeric accepts zero" {
    run validate_numeric "0" "count"
    [ "$status" -eq 0 ]
}

@test "validate_numeric rejects non-numeric input" {
    run validate_numeric "abc" "count"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "must be a positive integer" ]]
}

@test "validate_numeric rejects empty input" {
    run validate_numeric "" "count"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "must be a positive integer" ]]
}

@test "validate_numeric rejects negative numbers" {
    run validate_numeric "-5" "count"
    [ "$status" -eq 1 ]
}

@test "validate_numeric rejects floats" {
    run validate_numeric "3.14" "count"
    [ "$status" -eq 1 ]
}

# =========================================================================
# validate_range
# =========================================================================

@test "validate_range accepts value within range" {
    run validate_range "5" 1 10 "energy"
    [ "$status" -eq 0 ]
}

@test "validate_range accepts minimum boundary" {
    run validate_range "1" 1 10 "energy"
    [ "$status" -eq 0 ]
}

@test "validate_range accepts maximum boundary" {
    run validate_range "10" 1 10 "energy"
    [ "$status" -eq 0 ]
}

@test "validate_range rejects value below minimum" {
    run validate_range "0" 1 10 "energy"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "must be between 1 and 10" ]]
}

@test "validate_range rejects value above maximum" {
    run validate_range "11" 1 10 "energy"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "must be between 1 and 10" ]]
}

@test "validate_range rejects non-numeric input" {
    run validate_range "abc" 1 10 "energy"
    [ "$status" -eq 1 ]
}

# =========================================================================
# validate_file_exists
# =========================================================================

@test "validate_file_exists succeeds for existing file" {
    local target="$TEST_DIR/exists.txt"
    touch "$target"
    run validate_file_exists "$target" "test file"
    [ "$status" -eq 0 ]
}

@test "validate_file_exists fails for missing file" {
    run validate_file_exists "$TEST_DIR/nope.txt" "test file"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]]
}

# =========================================================================
# validate_path
# =========================================================================

@test "validate_path accepts path inside HOME" {
    local target="$TEST_DIR/subdir"
    mkdir -p "$target"
    run validate_path "$target"
    [ "$status" -eq 0 ]
}

@test "validate_path rejects traversal outside HOME" {
    run validate_path "/etc/passwd"
    [ "$status" -eq 1 ]
}

# =========================================================================
# die
# =========================================================================

@test "die exits with default code 1 and prints message to stderr" {
    run bash -c "
        export SYSTEM_LOG_FILE='$SYSTEM_LOG_FILE'
        export ENV_FILE='$ENV_FILE'
        export DOTFILES_DIR='$TEST_DIR'
        export HOME='$TEST_DIR'
        unset _COMMON_SH_LOADED COMMON_SH_LOADED _DOTFILES_CONFIG_LOADED _FILE_OPS_LOADED _DOTFILES_ENV_FILE_LOADED
        source '$BATS_TEST_DIRNAME/../scripts/lib/common.sh'
        die 'something broke'
    "
    [ "$status" -eq 1 ]
    [[ "$output" =~ "something broke" ]]
}

@test "die exits with custom exit code" {
    run bash -c "
        export SYSTEM_LOG_FILE='$SYSTEM_LOG_FILE'
        export ENV_FILE='$ENV_FILE'
        export DOTFILES_DIR='$TEST_DIR'
        export HOME='$TEST_DIR'
        unset _COMMON_SH_LOADED COMMON_SH_LOADED _DOTFILES_CONFIG_LOADED _FILE_OPS_LOADED _DOTFILES_ENV_FILE_LOADED
        source '$BATS_TEST_DIRNAME/../scripts/lib/common.sh'
        die 'file missing' 3
    "
    [ "$status" -eq 3 ]
    [[ "$output" =~ "file missing" ]]
}

# =========================================================================
# log_error, log_warn, log_info
# =========================================================================

@test "log_error writes ERROR entry to log file" {
    log_error "test error happened"
    assert_file_contains "$SYSTEM_LOG_FILE" "ERROR"
    assert_file_contains "$SYSTEM_LOG_FILE" "test error happened"
}

@test "log_warn writes WARN entry to log file" {
    log_warn "test warning"
    assert_file_contains "$SYSTEM_LOG_FILE" "WARN"
    assert_file_contains "$SYSTEM_LOG_FILE" "test warning"
}

@test "log_info writes INFO entry to log file" {
    log_info "informational message"
    assert_file_contains "$SYSTEM_LOG_FILE" "INFO"
    assert_file_contains "$SYSTEM_LOG_FILE" "informational message"
}
