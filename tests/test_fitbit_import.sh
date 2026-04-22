#!/usr/bin/env bats

# test_fitbit_import.sh - Bats coverage for fitbit import.

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment

    export DOTFILES_DIR
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    mkdir -p "$HOME/Downloads"
}

teardown() {
    teardown_test_environment
}

@test "fitbit_import.sh imports a steps CSV into normalized daily data" {
    cat > "$HOME/Downloads/steps.csv" <<'EOF'
Date,Steps
2026-03-20,4321
2026-03-21,5678
EOF

    run "$DOTFILES_DIR/scripts/fitbit_import.sh" import steps "$HOME/Downloads/steps.csv"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Imported steps"* ]]
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit/steps.txt" "2026-03-20|4321"
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit/steps.txt" "2026-03-21|5678"
}

@test "fitbit_import.sh merges later imports by date instead of duplicating days" {
    cat > "$HOME/Downloads/sleep_score_initial.csv" <<'EOF'
date_of_sleep,overall_sleep_score
2026-03-20,79
EOF

    cat > "$HOME/Downloads/sleep_score_update.csv" <<'EOF'
date_of_sleep,overall_sleep_score
2026-03-20,81
2026-03-21,84
EOF

    run "$DOTFILES_DIR/scripts/fitbit_import.sh" import sleep_score "$HOME/Downloads/sleep_score_initial.csv"
    [ "$status" -eq 0 ]

    run "$DOTFILES_DIR/scripts/fitbit_import.sh" import sleep_score "$HOME/Downloads/sleep_score_update.csv"

    [ "$status" -eq 0 ]
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit/sleep_score.txt" "2026-03-20|81"
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit/sleep_score.txt" "2026-03-21|84"

    run grep -c '^2026-03-20|' "$DOTFILES_DATA_DIR/fitbit/sleep_score.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "fitbit_import.sh auto imports multiple Fitbit CSVs and latest shows newest values" {
    mkdir -p "$HOME/Downloads/Fitbit Export"

    cat > "$HOME/Downloads/Fitbit Export/sleep_score.csv" <<'EOF'
date_of_sleep,overall_sleep_score
2026-03-20,80
2026-03-21,83
EOF

    cat > "$HOME/Downloads/Fitbit Export/resting_heart_rate.csv" <<'EOF'
Date,Resting Heart Rate
2026-03-20,61
EOF

    run "$DOTFILES_DIR/scripts/fitbit_import.sh" auto "$HOME/Downloads/Fitbit Export"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Imported 2 Fitbit file(s); skipped 0"* ]]
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit/sleep_score.txt" "2026-03-21|83"
    assert_file_contains "$DOTFILES_DATA_DIR/fitbit/resting_heart_rate.txt" "2026-03-20|61"

    run "$DOTFILES_DIR/scripts/fitbit_import.sh" latest

    [ "$status" -eq 0 ]
    [[ "$output" == *"sleep_score:"* ]]
    [[ "$output" == *"83 (2026-03-21)"* ]]
    [[ "$output" == *"resting_heart_rate:"* ]]
    [[ "$output" == *"61 (2026-03-20)"* ]]
}
