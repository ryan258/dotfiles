#!/usr/bin/env bats

# test_config_lib.sh - Bats coverage for config library.

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment

    # Point config.sh at a minimal .env so it does not load the real one.
    export ENV_FILE="$TEST_DIR/.env"
    cat > "$ENV_FILE" <<'DOTENV'
OPENROUTER_API_KEY=test-key-000
DEFAULT_MODEL=test/default-model
TECH_MODEL=test/tech-model
TECH_TEMPERATURE=0.15
DOTENV
    chmod 600 "$ENV_FILE"

    # Ensure DOTFILES_DIR resolves inside the test sandbox.
    export DOTFILES_DIR="$TEST_DIR"

    # Clear variables that might leak from the parent shell so config.sh
    # defaults are exercised cleanly.
    unset AI_BRIEFING_ENABLED AI_STATUS_ENABLED AI_REFLECTION_ENABLED
    unset DEFAULT_DAILY_SPOONS STALE_TASK_DAYS

    # shellcheck disable=SC1090
    source "$BATS_TEST_DIRNAME/../scripts/lib/config.sh"
}

teardown() {
    teardown_test_environment
}

# ---------------------------------------------------------------------------
# Path variables
# ---------------------------------------------------------------------------

@test "DATA_DIR is set after sourcing config.sh" {
    [ -n "$DATA_DIR" ]
    [[ "$DATA_DIR" == *"dotfiles-data"* ]]
}

@test "CACHE_DIR and CONFIG_DIR are set" {
    [ -n "$CACHE_DIR" ]
    [ -n "$CONFIG_DIR" ]
    [[ "$CACHE_DIR" == *"dotfiles"* ]]
    [[ "$CONFIG_DIR" == *"dotfiles"* ]]
}

@test "TODO_FILE points inside DATA_DIR" {
    [ -n "$TODO_FILE" ]
    [[ "$TODO_FILE" == "$DATA_DIR/todo.txt" ]]
}

@test "key data-file variables are set" {
    [ -n "$JOURNAL_FILE" ]
    [ -n "$DONE_FILE" ]
    [ -n "$HEALTH_FILE" ]
    [ -n "$SPOON_LOG" ]
    [ -n "$TIME_LOG" ]
    [ -n "$SYSTEM_LOG" ]
    [ -n "$FOCUS_FILE" ]
    [ -n "$BRIEFING_CACHE_FILE" ]

    [[ "$JOURNAL_FILE" == "$DATA_DIR/journal.txt" ]]
    [[ "$DONE_FILE" == "$DATA_DIR/todo_done.txt" ]]
    [[ "$HEALTH_FILE" == "$DATA_DIR/health.txt" ]]
    [[ "$SPOON_LOG" == "$DATA_DIR/spoons.txt" ]]
}

# ---------------------------------------------------------------------------
# ensure_data_dirs()
# ---------------------------------------------------------------------------

@test "ensure_data_dirs creates expected directories" {
    # config.sh calls ensure_data_dirs on source, so dirs should already exist.
    [ -d "$DATA_DIR" ]
    [ -d "$CACHE_DIR" ]
    [ -d "$CONFIG_DIR" ]
}

@test "ensure_data_dirs is idempotent" {
    # Running a second time should not error.
    run ensure_data_dirs
    [ "$status" -eq 0 ]
    [ -d "$DATA_DIR" ]
}

# ---------------------------------------------------------------------------
# get_model()
# ---------------------------------------------------------------------------

@test "get_model returns dispatcher-specific model when set" {
    run get_model "TECH"
    [ "$status" -eq 0 ]
    [ "$output" = "test/tech-model" ]
}

@test "get_model falls back to DEFAULT_MODEL for unknown type" {
    run get_model "NONEXISTENT"
    [ "$status" -eq 0 ]
    [ "$output" = "test/default-model" ]
}

@test "get_model falls back to MODEL_FALLBACK when DEFAULT_MODEL is unset" {
    # Use an .env without DEFAULT_MODEL so config.sh does not re-set it.
    local bare_env="$TEST_DIR/.env.bare"
    printf 'OPENROUTER_API_KEY=test-key-000\n' > "$bare_env"
    chmod 600 "$bare_env"

    run bash -c '
        export HOME="'"$TEST_DIR"'"
        export ENV_FILE="'"$bare_env"'"
        export DOTFILES_DIR="'"$DOTFILES_DIR"'"
        unset DEFAULT_MODEL
        unset _DOTFILES_CONFIG_LOADED _DOTFILES_ENV_FILE_LOADED
        source "'"$BATS_TEST_DIRNAME"'/../scripts/lib/config.sh"
        get_model "BOGUS"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *":free"* ]]
}

# ---------------------------------------------------------------------------
# get_temperature()
# ---------------------------------------------------------------------------

@test "get_temperature returns env override when set" {
    run get_temperature "TECH"
    [ "$status" -eq 0 ]
    [ "$output" = "0.15" ]
}

@test "get_temperature returns built-in default for type without env" {
    run get_temperature "CREATIVE"
    [ "$status" -eq 0 ]
    [ "$output" = "0.7" ]
}

@test "get_output_dir covers extended dispatcher types from DHP_OUTPUT_BASE" {
    run bash -c '
        export HOME="'"$TEST_DIR"'"
        export ENV_FILE="'"$ENV_FILE"'"
        export DOTFILES_DIR="'"$DOTFILES_DIR"'"
        export DHP_OUTPUT_BASE="'"$TEST_DIR"'/outputs"
        unset DHP_FINANCE_OUTPUT_DIR DHP_MORPHLING_OUTPUT_DIR DHP_PROJECT_OUTPUT_DIR DHP_COACH_OUTPUT_DIR
        unset _DOTFILES_CONFIG_LOADED _DOTFILES_ENV_FILE_LOADED
        source "'"$BATS_TEST_DIRNAME"'/../scripts/lib/config.sh"
        printf "%s\n" \
            "$(get_output_dir FINANCE)" \
            "$(get_output_dir MORPHLING)" \
            "$(get_output_dir PROJECT)" \
            "$(get_output_dir COACH)"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"$TEST_DIR/outputs/Strategy/Finance"* ]]
    [[ "$output" == *"$TEST_DIR/outputs/Morphling"* ]]
    [[ "$output" == *"$TEST_DIR/outputs/Strategy/Projects"* ]]
    [[ "$output" == *"$TEST_DIR/outputs/Strategy/Coach"* ]]
}

# ---------------------------------------------------------------------------
# is_free_model()
# ---------------------------------------------------------------------------

@test "is_free_model returns 0 for free models" {
    run is_free_model "nvidia/nemotron-3-super-120b-a12b:free"
    [ "$status" -eq 0 ]
}

@test "is_free_model returns non-zero for paid models" {
    run is_free_model "openai/gpt-4o"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Feature flag defaults
# ---------------------------------------------------------------------------

@test "AI_BRIEFING_ENABLED defaults to true" {
    [ "$AI_BRIEFING_ENABLED" = "true" ]
}

@test "AI_STATUS_ENABLED defaults to false when unset" {
    run bash -c '
        export HOME="'"$TEST_DIR"'"
        export ENV_FILE="'"$ENV_FILE"'"
        export DOTFILES_DIR="'"$DOTFILES_DIR"'"
        unset AI_STATUS_ENABLED
        unset _DOTFILES_CONFIG_LOADED _DOTFILES_ENV_FILE_LOADED
        source "'"$BATS_TEST_DIRNAME"'/../scripts/lib/config.sh"
        echo "$AI_STATUS_ENABLED"
    '
    [ "$status" -eq 0 ]
    [ "$output" = "false" ]
}

@test "DEFAULT_DAILY_SPOONS has a sane default" {
    [ -n "$DEFAULT_DAILY_SPOONS" ]
    [ "$DEFAULT_DAILY_SPOONS" -gt 0 ]
}

# ---------------------------------------------------------------------------
# Double-source guard
# ---------------------------------------------------------------------------

@test "sourcing config.sh twice does not error" {
    # Run in a subshell so the readonly guard variable is fresh.
    run bash -c '
        export HOME="'"$TEST_DIR"'"
        export ENV_FILE="'"$ENV_FILE"'"
        export DOTFILES_DIR="'"$DOTFILES_DIR"'"
        source "'"$BATS_TEST_DIRNAME"'/../scripts/lib/config.sh"
        source "'"$BATS_TEST_DIRNAME"'/../scripts/lib/config.sh"
        echo "ok"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

# ---------------------------------------------------------------------------
# .env loading
# ---------------------------------------------------------------------------

@test "config.sh loads variables from .env" {
    # OPENROUTER_API_KEY was set in our test .env
    [ "$OPENROUTER_API_KEY" = "test-key-000" ]
}
