#!/usr/bin/env bats

setup() {
    export TEST_DATA_DIR="$(mktemp -d)"
    export HOME="$TEST_DATA_DIR"
    mkdir -p "$TEST_DATA_DIR/.config/dotfiles-data"
    
    # Copy scripts to test dir to ensure relative paths work if needed
    # But meds.sh uses SCRIPT_DIR to find lib/date_utils.sh
    # So we should run it from its original location but with HOME overridden
    # OR copy everything.
    # meds.sh finds date_utils via relative path.
    # Let's use the real script path.
}

teardown() {
    rm -rf "$TEST_DATA_DIR"
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
