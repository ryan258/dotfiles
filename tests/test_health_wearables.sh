#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment

    export DOTFILES_DIR
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    mkdir -p "$DOTFILES_DATA_DIR/fitbit"
}

teardown() {
    teardown_test_environment
}

@test "health.sh summary shows Fitbit metrics even without manual health data" {
    cat > "$DOTFILES_DATA_DIR/fitbit/steps.txt" <<'EOF'
2026-03-25|7111
2026-03-26|822
EOF

    cat > "$DOTFILES_DATA_DIR/fitbit/sleep_minutes.txt" <<'EOF'
2026-03-26|257
EOF

    cat > "$DOTFILES_DATA_DIR/fitbit/resting_heart_rate.txt" <<'EOF'
2026-03-26|73
EOF

    cat > "$DOTFILES_DATA_DIR/fitbit/hrv.txt" <<'EOF'
2026-03-26|67
EOF

    run "$DOTFILES_DIR/scripts/health.sh" summary

    [ "$status" -eq 0 ]
    [[ "$output" == *"Fitbit sleep: 257m (2026-03-26)"* ]]
    [[ "$output" == *"Fitbit resting HR: 73 (2026-03-26)"* ]]
    [[ "$output" == *"Fitbit HRV: 67 (2026-03-26)"* ]]
    [[ "$output" == *"Fitbit steps: 822 (2026-03-26)"* ]]
}

@test "health.sh dashboard includes wearable section and sleep by energy bands" {
    cat > "$DOTFILES_DATA_DIR/health.txt" <<'EOF'
ENERGY|2026-03-24 08:00|3
ENERGY|2026-03-25 08:00|8
SYMPTOM|2026-03-25 10:00|brain fog
EOF

    cat > "$DOTFILES_DATA_DIR/fitbit/sleep_minutes.txt" <<'EOF'
2026-03-24|360
2026-03-25|480
EOF

    cat > "$DOTFILES_DATA_DIR/fitbit/steps.txt" <<'EOF'
2026-03-24|2000
2026-03-25|7000
EOF

    cat > "$DOTFILES_DATA_DIR/fitbit/resting_heart_rate.txt" <<'EOF'
2026-03-24|75
2026-03-25|68
EOF

    run "$DOTFILES_DIR/scripts/health.sh" dashboard

    [ "$status" -eq 0 ]
    [[ "$output" == *"Wearable Signals (30d):"* ]]
    [[ "$output" == *"sleep: avg 420m over 2 day(s); latest 480m (2026-03-25)"* ]]
    [[ "$output" == *"steps: avg 4500 over 2 day(s); latest 7000 (2026-03-25)"* ]]
    [[ "$output" == *"sleep on low-energy days (1-4): 360m (n=1)"* ]]
    [[ "$output" == *"sleep on high-energy days (7-10): 480m (n=1)"* ]]
}
