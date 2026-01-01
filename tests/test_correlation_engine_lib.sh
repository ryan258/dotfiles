#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    # Source the library
    source "$BATS_TEST_DIRNAME/../scripts/lib/correlation_engine.sh"
}

teardown() {
    teardown_test_environment
}

@test "correlate_two_datasets returns logic correlation" {
    # Generate mock data
    cat <<EOF > "$TEST_DIR/data1.csv"
2025-01-01|10
2025-01-02|20
2025-01-03|30
2025-01-04|40
2025-01-05|50
EOF
    cat <<EOF > "$TEST_DIR/data2.csv"
2025-01-01|1
2025-01-02|2
2025-01-03|3
2025-01-04|4
2025-01-05|5
EOF
    
    # Perfect positive correlation (r=1.0)
    # Default cols: 0-based index. 
    # file1: date=0, val=1
    
    run correlate_two_datasets "$TEST_DIR/data1.csv" "$TEST_DIR/data2.csv" 0 1 0 1
    [ "$status" -eq 0 ]
    [ "$output" = "1.0000" ]
}

@test "correlate_two_datasets detects negative correlation" {
        cat <<EOF > "$TEST_DIR/data1.csv"
2025-01-01|10
2025-01-02|20
2025-01-03|30
2025-01-04|40
2025-01-05|50
EOF
    cat <<EOF > "$TEST_DIR/data2.csv"
2025-01-01|5
2025-01-02|4
2025-01-03|3
2025-01-04|2
2025-01-05|1
EOF
    
    run correlate_two_datasets "$TEST_DIR/data1.csv" "$TEST_DIR/data2.csv" 0 1 0 1
    [ "$status" -eq 0 ]
    [ "$output" = "-1.0000" ]
}

@test "generate_insight_text interprets valid correlations" {
    run generate_insight_text "0.85"
    [[ "$output" =~ "strong positive" ]]
    
    run generate_insight_text "-0.5"
    [[ "$output" =~ "moderate negative" ]]
    
    run generate_insight_text "0.01"
    [[ "$output" =~ "negligible" ]]
}

@test "generate_insight_text handles invalid input" {
    run generate_insight_text "notanumber"
    [[ "$output" =~ "Invalid" ]]
}
