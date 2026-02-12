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

@test "meds refill adds a refill date" {
    run bash "$BATS_TEST_DIRNAME/../scripts/meds.sh" refill "TestMed" "2025-12-01"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Set refill date for TestMed" ]]
    [ -f "$TEST_DATA_DIR/.config/dotfiles-data/medications.txt" ]
    grep -q "REFILL|TestMed|2025-12-01" "$TEST_DATA_DIR/.config/dotfiles-data/medications.txt"
}

@test "meds check-refill warns about upcoming refills" {
    # Set a refill date for tomorrow
    tomorrow=$(date -v+1d +%Y-%m-%d 2>/dev/null || date -d "+1 day" +%Y-%m-%d)

    echo "REFILL|TestMed|$tomorrow" > "$TEST_DATA_DIR/.config/dotfiles-data/medications.txt"

    run bash "$BATS_TEST_DIRNAME/../scripts/meds.sh" check-refill

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Refill due soon" ]]
    [[ "$output" =~ "TestMed" ]]
}

@test "meds check-refill warns about overdue refills" {
    # Set a refill date for yesterday
    yesterday=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "-1 day" +%Y-%m-%d)

    echo "REFILL|TestMed|$yesterday" > "$TEST_DATA_DIR/.config/dotfiles-data/medications.txt"

    run bash "$BATS_TEST_DIRNAME/../scripts/meds.sh" check-refill

    [ "$status" -eq 0 ]
    [[ "$output" =~ "REFILL OVERDUE" ]]
    [[ "$output" =~ "TestMed" ]]
}

@test "meds check-refill is silent if refill is far in future" {
    # Set a refill date for 30 days from now
    future=$(date -v+30d +%Y-%m-%d 2>/dev/null || date -d "+30 days" +%Y-%m-%d)

    echo "REFILL|TestMed|$future" > "$TEST_DATA_DIR/.config/dotfiles-data/medications.txt"

    run bash "$BATS_TEST_DIRNAME/../scripts/meds.sh" check-refill

    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
}

@test "meds check flags missing doses when due" {
    today="2025-01-02"
    echo "MED|TestMed|morning" > "$TEST_DATA_DIR/.config/dotfiles-data/medications.txt"

    run env MEDS_TODAY_OVERRIDE="$today" MEDS_CURRENT_HOUR_OVERRIDE="9" \
        bash "$BATS_TEST_DIRNAME/../scripts/meds.sh" check

    [ "$status" -eq 0 ]
    [[ "$output" =~ "NOT TAKEN YET" ]]
    [[ ! "$output" =~ "All scheduled medications taken" ]]
}

@test "meds check confirms doses when taken" {
    today="2025-01-02"
    {
        echo "MED|TestMed|morning"
        echo "DOSE|$today 08:00|TestMed"
    } > "$TEST_DATA_DIR/.config/dotfiles-data/medications.txt"

    run env MEDS_TODAY_OVERRIDE="$today" MEDS_CURRENT_HOUR_OVERRIDE="9" \
        bash "$BATS_TEST_DIRNAME/../scripts/meds.sh" check

    [ "$status" -eq 0 ]
    [[ "$output" =~ "taken" ]]
    [[ "$output" =~ "All scheduled medications taken" ]]
}
