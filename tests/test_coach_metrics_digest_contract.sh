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
    source "$BATS_TEST_DIRNAME/../scripts/lib/health_ops.sh"
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

@test "coach_build_behavior_digest includes wearable context when Fitbit data exists" {
    mkdir -p "$DATA_DIR/fitbit"
    cat > "$DATA_DIR/fitbit/sleep_minutes.txt" <<'EOF'
2026-03-26|257
EOF
    cat > "$DATA_DIR/fitbit/resting_heart_rate.txt" <<'EOF'
2026-03-26|73
EOF
    cat > "$DATA_DIR/fitbit/hrv.txt" <<'EOF'
2026-03-26|67
EOF
    cat > "$DATA_DIR/fitbit/steps.txt" <<'EOF'
2026-03-26|822
EOF

    run coach_build_behavior_digest "2026-03-26" "7" "30" "" ""

    assert_success
    assert_output_contains "Wearable context:"
    assert_output_contains "Fitbit sleep: 4h 17m (2026-03-26)"
    assert_output_contains "Fitbit resting HR: 73 (2026-03-26)"
    assert_output_contains "Fitbit HRV: 67 (2026-03-26)"
    assert_output_contains "Fitbit steps: 822 (2026-03-26)"
}

@test "coach_build_behavior_digest includes both latest and average energy fog context" {
    cat > "$DATA_DIR/health.txt" <<'EOF'
ENERGY|2026-03-23 01:14|2
FOG|2026-03-23 01:14|8
ENERGY|2026-03-23 10:54|10
FOG|2026-03-23 10:54|2
ENERGY|2026-03-23 23:24|3
FOG|2026-03-23 23:24|7
ENERGY|2026-03-26 13:02|7
FOG|2026-03-26 13:02|3
EOF

    run coach_build_behavior_digest "2026-03-26" "7" "30" "" ""

    assert_success
    assert_output_contains "latest_energy=7 (2026-03-26 13:02), latest_fog=3 (2026-03-26 13:02), avg_energy=5.5, avg_fog=5.0"
}

@test "coach_build_behavior_digest includes focus-related strategy evidence fields" {
    cat > "$FOCUS_FILE" <<'EOF'
Architecture review memo
EOF
    cat > "$JOURNAL_FILE" <<'EOF'
2026-03-26 08:00:00|Architecture review memo outline
EOF
    mkdir -p "$DOTFILES_DIR/scripts"
    cat > "$DOTFILES_DIR/scripts/drive.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "recent" && "${2:-}" == "1" ]]; then
  cat <<'JSON'
[{"id":"doc-1","name":"Architecture review memo"}]
JSON
elif [[ "${1:-}" == "read" && "${2:-}" == "doc-1" ]]; then
  printf 'Architecture review memo excerpt'
else
  cat <<'JSON'
[{"id":"doc-1","name":"Architecture review memo"},{"id":"doc-2","name":"System design notes"}]
JSON
fi
EOF
    chmod +x "$DOTFILES_DIR/scripts/drive.sh"

    run coach_build_behavior_digest "2026-03-26" "7" "30" "" ""

    assert_success
    assert_output_contains "journal_focus_hits=1"
    assert_output_contains "drive_focus_hits_today=1"
    assert_output_contains "drive_focus_hits_week=2"
    assert_output_contains "drive_top_file_id=doc-1"
    assert_output_contains "drive_top_file_name=Architecture review memo"
    assert_output_contains "drive_top_file_snippet_b64="
    assert_output_contains "strategy_evidence_sources=journal,drive"
}
