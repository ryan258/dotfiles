#!/usr/bin/env bats

# test_coach_prompts.sh - Bats coverage for coach framing prompts.

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    setup_test_environment
    export PROMPTS_LIB="$BATS_TEST_DIRNAME/../scripts/lib/coach_prompts.sh"
}

teardown() {
    teardown_test_environment
}

@test "coach_prompts can be sourced without coach metrics" {
    run bash -c "source '$PROMPTS_LIB'; coach_build_framing_template status"

    [ "$status" -eq 0 ]
    [[ "$output" == *"calm coach"* ]]
    [[ "$output" == *"ground truth"* ]]
}

@test "coach_build_framing_prompt appends deterministic brief" {
    run bash -c "source '$PROMPTS_LIB'; coach_build_framing_prompt status 'Brief body.'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deterministic brief:"* ]]
    [[ "$output" == *"Brief body."* ]]
}
