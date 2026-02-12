#!/usr/bin/env bats

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    setup_test_environment
    
    # Stage scripts and python file
    mkdir -p "$TEST_DIR/scripts/lib"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/common.sh" "$TEST_DIR/scripts/lib/"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$TEST_DIR/scripts/lib/"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/file_ops.sh" "$TEST_DIR/scripts/lib/"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/correlation_engine.sh" "$TEST_DIR/scripts/lib/"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/correlate.py" "$TEST_DIR/scripts/lib/"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/time_tracking.sh" "$TEST_DIR/scripts/lib/"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/date_utils.sh" "$TEST_DIR/scripts/lib/"
    cp "$BATS_TEST_DIRNAME/../scripts/correlate.sh" "$TEST_DIR/scripts/"
    cp "$BATS_TEST_DIRNAME/../scripts/generate_report.sh" "$TEST_DIR/scripts/"
    chmod +x "$TEST_DIR/scripts/"*.sh
    
    # Create dummy data
    mkdir -p "$DATA_DIR"
    
    # Dummy Spoons: BUDGET|YYYY-MM-DD|count
    # Using pipe as delimiter strictly
    echo "BUDGET|2025-01-01|12" > "$DATA_DIR/spoons.txt"
    echo "BUDGET|2025-01-02|10" >> "$DATA_DIR/spoons.txt"
    # SPEND|YYYY-MM-DD|HH:MM|count|activity|remaining
    echo "SPEND|2025-01-01|09:00|2|Meeting|10" >> "$DATA_DIR/spoons.txt"
    echo "SPEND|2025-01-01|12:00|2|Coding|8" >> "$DATA_DIR/spoons.txt"
    
    # Dummy Time: START|id|text|timestamp, STOP|id|timestamp
    # Format: START|id|text|YYYY-MM-DD HH:MM:SS
    echo "START|1|Task 1|2025-01-01 09:00:00" > "$DATA_DIR/time_tracking.txt"
    echo "STOP|1|2025-01-01 10:00:00" >> "$DATA_DIR/time_tracking.txt"
    echo "START|2|Task 2|2025-01-01 10:30:00" >> "$DATA_DIR/time_tracking.txt"
    echo "STOP|2|2025-01-01 12:30:00" >> "$DATA_DIR/time_tracking.txt"
    
    # We need a csv for 'correlate run' to work without aggregation
    # Let's make a simple csv for direct testing of correlate.sh
    echo "date|v1" > "$DATA_DIR/dataset1.csv"
    echo "2025-01-01|10" >> "$DATA_DIR/dataset1.csv"
    echo "2025-01-02|20" >> "$DATA_DIR/dataset1.csv"
    echo "2025-01-03|30" >> "$DATA_DIR/dataset1.csv"
    echo "2025-01-04|40" >> "$DATA_DIR/dataset1.csv"
    echo "2025-01-05|50" >> "$DATA_DIR/dataset1.csv"
    
    echo "date|v2" > "$DATA_DIR/dataset2.csv"
    echo "2025-01-01|100" >> "$DATA_DIR/dataset2.csv"
    echo "2025-01-02|200" >> "$DATA_DIR/dataset2.csv"
    echo "2025-01-03|300" >> "$DATA_DIR/dataset2.csv"
    echo "2025-01-04|400" >> "$DATA_DIR/dataset2.csv"
    echo "2025-01-05|500" >> "$DATA_DIR/dataset2.csv"
    
    export DATA_DIR="$DATA_DIR"
    export HOME="$TEST_DIR"
}

teardown() {
    teardown_test_environment
}

@test "correlate.sh run calculates correlation" {
    run "$TEST_DIR/scripts/correlate.sh" run "$DATA_DIR/dataset1.csv" "$DATA_DIR/dataset2.csv" 0 1 0 1
    echo "Output: $output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1.0000" ]]
}

@test "generate_report.sh creates report file" {
    # Set date to match dummy data
    # (Mocking date command is hard in integration tests running subshells, 
    # so we might verify the script runs without error for TODAY (which has no data) 
    # OR we just check the file is created with headers)
    
    run "$TEST_DIR/scripts/generate_report.sh" daily
    echo "Report Output: $output"
    [ "$status" -eq 0 ]
    assert_file_exists "$DATA_DIR/reports/report-daily-$(date +%Y-%m-%d).md"
    
    # Check headers
    assert_file_contains "$DATA_DIR/reports/report-daily-$(date +%Y-%m-%d).md" "## ⏱️ Time Tracking"
    assert_file_contains "$DATA_DIR/reports/report-daily-$(date +%Y-%m-%d).md" "## 🥣 Spoon Budget"
}

@test "generate_report.sh handles missing data gracefully" {
    rm "$DATA_DIR/time_tracking.txt"
    rm "$DATA_DIR/spoons.txt"
    
    run "$TEST_DIR/scripts/generate_report.sh" daily
    [ "$status" -eq 0 ]
    
    # Verify content indicates 0 or no data
    run cat "$DATA_DIR/reports/report-daily-$(date +%Y-%m-%d).md"
    [[ "$output" =~ "Total Focus Time:** 0h 0m" ]]
    [[ "$output" =~ "No data" ]]
}
