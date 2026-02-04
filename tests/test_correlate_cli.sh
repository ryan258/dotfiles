#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"

setup() {
    setup_test_environment
    CORRELATE_SCRIPT="$BATS_TEST_DIRNAME/../scripts/correlate.sh"

    cat <<EOF > "$TEST_DIR/data.csv"
2026-01-01|1
2026-01-02|2
2026-01-03|3
2026-01-04|4
2026-01-05|5
EOF
}

teardown() {
    teardown_test_environment
}

@test "correlate.sh find-patterns prints summary" {
    run bash -c "cd \"$TEST_DIR\" && \"$CORRELATE_SCRIPT\" find-patterns data.csv 0 1"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Patterns for" ]]
    [[ "$output" =~ "Trend" ]]
}

@test "correlate.sh explain interprets coefficient" {
    run bash "$CORRELATE_SCRIPT" explain 0.5
    [ "$status" -eq 0 ]
    [[ "$output" =~ "moderate positive" ]]
}
