#!/usr/bin/env bats

# test_coach_metrics_digest_contract.sh - Contract coverage for coach digest keys.

load helpers/test_helpers.sh
load helpers/assertions.sh

assert_success() {
    if [ "$status" -ne 0 ]; then
        echo "Expected success but got exit code: $status" >&2
        echo "Output: $output" >&2
        return 1
    fi
}

assert_output_contains() {
    local expected="$1"
    if [[ "$output" != *"$expected"* ]]; then
        echo "Expected output to contain: $expected" >&2
        echo "Actual output: $output" >&2
        return 1
    fi
}

setup() {
    setup_test_environment
    export DOTFILES_DIR="$TEST_DIR/dotfiles"
    export PROJECTS_DIR="$TEST_DIR/Projects"
    mkdir -p "$DOTFILES_DIR" "$PROJECTS_DIR"

    source "$BATS_TEST_DIRNAME/../scripts/lib/config.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/common.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/date_utils.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/focus_relevance.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/coach_metrics.sh"
}

teardown() {
    teardown_test_environment
}

@test "coach_build_behavior_digest preserves fields consumed by coach_brief" {
    cat > "$TODO_FILE" <<'EOF'
1|2026-03-01|old stale task
2|2026-03-26|active task
EOF
    cat > "$DONE_FILE" <<'EOF'
2026-03-25 10:00:00|finish parser prep
2026-03-26 11:00:00|ship parser fix
EOF
    cat > "$JOURNAL_FILE" <<'EOF'
2026-03-25 08:00:00|Parser fix notes
2026-03-26 08:30:00|Parser ship plan
EOF
    cat > "$HEALTH_FILE" <<'EOF'
ENERGY|2026-03-26 09:00|5
FOG|2026-03-26 09:05|4
EOF
    cat > "$SPOON_LOG" <<'EOF'
BUDGET|2026-03-26|7
SPEND|2026-03-26|12:00|3|work|4
EOF
    cat > "$FOCUS_FILE" <<'EOF'
Ship parser fix
EOF

    run coach_build_behavior_digest \
        "2026-03-26" \
        "7" \
        "30" \
        $'  - dotfiles (pushed today)' \
        $'  - dotfiles: ship parser fix (abc1234)'

    assert_success
    assert_output_contains "Tactical window: 7d ending"
    assert_output_contains "open_tasks="
    assert_output_contains "completed_tasks="
    assert_output_contains "latest_energy="
    assert_output_contains "avg_energy="
    assert_output_contains "strategy_evidence_sources="
    assert_output_contains "Working signals:"
    assert_output_contains "Drift risks:"
    assert_output_contains "Data quality flags:"
}
