#!/usr/bin/env bats

# test_coach_framing.sh - Contract tests for the Phase 4 framing-prompt builder.
#
# These tests lock in the deletion signal from DOT-ROADMAP.md section 10.1
# step 5: once the framing template stays free of computed facts, the
# hallucination guards and post-generation evidence cleanup in coach_prompts.sh
# can be deleted safely.

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    setup_test_environment

    source "$BATS_TEST_DIRNAME/../scripts/lib/config.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/common.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/date_utils.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/focus_relevance.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/coach_metrics.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/coach_prompts.sh"
}

teardown() {
    teardown_test_environment
}

assert_framing_template_has_no_facts() {
    local template="$1"
    local flow="$2"

    # No metric keys leak from the digest.
    [[ "$template" != *"latest_energy"* ]] || { echo "metric key 'latest_energy' leaked into $flow template" >&2; return 1; }
    [[ "$template" != *"latest_fog"* ]] || { echo "metric key 'latest_fog' leaked into $flow template" >&2; return 1; }
    [[ "$template" != *"open_tasks"* ]] || { echo "metric key 'open_tasks' leaked into $flow template" >&2; return 1; }
    [[ "$template" != *"avg_energy"* ]] || { echo "metric key 'avg_energy' leaked into $flow template" >&2; return 1; }
    [[ "$template" != *"stale_tasks"* ]] || { echo "metric key 'stale_tasks' leaked into $flow template" >&2; return 1; }
    [[ "$template" != *"commit_coherence"* ]] || { echo "metric key 'commit_coherence' leaked into $flow template" >&2; return 1; }

    # No specific dates (YYYY format catches dates and years).
    if printf '%s' "$template" | grep -qE '\b(19|20)[0-9]{2}\b'; then
        echo "date-like token leaked into $flow template" >&2
        return 1
    fi

    # No bullet lines in the template itself. The brief carries bullets.
    if printf '%s\n' "$template" | grep -qE '^\s*-\s'; then
        echo "bullet line leaked into $flow template" >&2
        return 1
    fi

    # No repo name examples that the AI could pattern-match against.
    [[ "$template" != *"dotfiles"* ]] || { echo "repo name 'dotfiles' leaked into $flow template" >&2; return 1; }
    [[ "$template" != *"ai-staff-hq"* ]] || { echo "repo name 'ai-staff-hq' leaked into $flow template" >&2; return 1; }

    # No multi-digit numbers (counts, percentages, time windows).
    if printf '%s' "$template" | grep -qE '[0-9]{2,}'; then
        echo "multi-digit number leaked into $flow template" >&2
        return 1
    fi
}

@test "coach_build_framing_template has no deterministic facts for startday flow" {
    local template
    template=$(coach_build_framing_template "startday")

    [ -n "$template" ]
    [[ "$template" == *"calm coach"* ]]
    [[ "$template" == *"framing for today"* ]]
    assert_framing_template_has_no_facts "$template" "startday"
}

@test "coach_build_framing_template has no deterministic facts for status flow" {
    local template
    template=$(coach_build_framing_template "status")

    [ -n "$template" ]
    [[ "$template" == *"framing for right now"* ]]
    assert_framing_template_has_no_facts "$template" "status"
}

@test "coach_build_framing_template has no deterministic facts for goodevening flow" {
    local template
    template=$(coach_build_framing_template "goodevening")

    [ -n "$template" ]
    [[ "$template" == *"framing for what closed today"* ]]
    assert_framing_template_has_no_facts "$template" "goodevening"
}

@test "coach_build_framing_template defaults to status flow when no flow is given" {
    local template
    template=$(coach_build_framing_template)

    [ -n "$template" ]
    [[ "$template" == *"framing for right now"* ]]
    assert_framing_template_has_no_facts "$template" "default"
}

@test "coach_build_framing_prompt appends the deterministic brief under a labeled section" {
    local brief
    brief=$(cat <<'EOF'
Coach Brief
Flow: status
Date: 2026-05-18
Mode: LOCKED
Focus: Ship the deterministic brief

Current Facts
- Window: 7d ending 2026-05-18.
- Tasks: 3 open, 1 stale, 2 completed in the tactical window.
EOF
)
    local prompt
    prompt=$(coach_build_framing_prompt "status" "$brief")

    [[ "$prompt" == *"calm coach"* ]]
    [[ "$prompt" == *"Deterministic brief:"* ]]
    [[ "$prompt" == *"Coach Brief"* ]]
    [[ "$prompt" == *"Flow: status"* ]]
    [[ "$prompt" == *"Focus: Ship the deterministic brief"* ]]
    [[ "$prompt" == *"Tasks: 3 open"* ]]

    # The template precedes the brief in the assembled prompt.
    template_line=$(printf '%s\n' "$prompt" | awk '/calm coach/ {print NR; exit}')
    brief_line=$(printf '%s\n' "$prompt" | awk '/^Deterministic brief:/ {print NR; exit}')
    [ "$template_line" -lt "$brief_line" ]
}

@test "coaching facade exposes coach_build_framing_template and coach_build_framing_prompt" {
    source "$BATS_TEST_DIRNAME/../scripts/lib/coach_scoring.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/coach_brief.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/coaching.sh"

    run coaching_build_framing_template "startday"
    [ "$status" -eq 0 ]
    [[ "$output" == *"calm coach"* ]]

    run coaching_build_framing_prompt "status" "Brief body."
    [ "$status" -eq 0 ]
    [[ "$output" == *"calm coach"* ]]
    [[ "$output" == *"Deterministic brief:"* ]]
    [[ "$output" == *"Brief body."* ]]
}
