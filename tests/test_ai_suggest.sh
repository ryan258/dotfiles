#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    # Alias for backward compatibility with test assertions
    export TEST_DATA_DIR="$TEST_DIR"
}

teardown() {
    teardown_test_environment
}

@test "suggests Stoic Coach on low energy days" {
    echo "ENERGY|$(date +%Y-%m-%d) 08:00|2" > "$TEST_DATA_DIR/.config/dotfiles-data/health.txt"

    run bash "$BATS_TEST_DIRNAME/../scripts/ai_suggest.sh"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Stoic Coach" ]]
    [[ "$output" =~ "Low energy detected" ]]
}

@test "suggests Deep Work on high energy days" {
    echo "ENERGY|$(date +%Y-%m-%d) 08:00|9" > "$TEST_DATA_DIR/.config/dotfiles-data/health.txt"

    run bash "$BATS_TEST_DIRNAME/../scripts/ai_suggest.sh"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Strategy" ]] || [[ "$output" =~ "Deep Work" ]]
    [[ "$output" =~ "High energy detected" ]]
}

@test "warns about overdue medications" {
    echo "MED|TestMed|00:00" > "$TEST_DATA_DIR/.config/dotfiles-data/medications.txt"

    cat > "$TEST_DATA_DIR/mock_meds.sh" <<'EOF'
#!/usr/bin/env bash
echo "💊 MEDICATION CHECK:"
echo "  ⚠️  TestMed (00:00) - NOT TAKEN YET"
EOF
    chmod +x "$TEST_DATA_DIR/mock_meds.sh"

    run env MEDS_SCRIPT_OVERRIDE="$TEST_DATA_DIR/mock_meds.sh" bash "$BATS_TEST_DIRNAME/../scripts/ai_suggest.sh"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Health Alert" ]]
    [[ "$output" =~ "meds check" ]]
}

@test "handles missing health data gracefully" {
    run bash "$BATS_TEST_DIRNAME/../scripts/ai_suggest.sh"
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "Energy detected" ]]
}
