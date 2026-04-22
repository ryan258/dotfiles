#!/usr/bin/env bats

# test_journal.sh - Bats coverage for journal.

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    export TEST_DATA_DIR="$TEST_DIR/.config/dotfiles-data"
}

teardown() {
    teardown_test_environment
}

_journal_path() {
    printf '%s' "$TEST_DATA_DIR/journal.txt"
}

_focus_path() {
    printf '%s' "$TEST_DATA_DIR/daily_focus.txt"
}

@test "journal list defaults to five most recent entries" {
    cat > "$(_journal_path)" <<'EOF'
2026-04-17 08:00:00|Entry one
2026-04-18 08:00:00|Entry two
2026-04-19 08:00:00|Entry three
2026-04-20 08:00:00|Entry four
2026-04-21 08:00:00|Entry five
2026-04-22 08:00:00|Entry six
EOF

    run bash "$BATS_TEST_DIRNAME/../scripts/journal.sh" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"1. 2026-04-22 08:00:00|Entry six"* ]]
    [[ "$output" == *"5. 2026-04-18 08:00:00|Entry two"* ]]
    [[ "$output" != *"Entry one"* ]]
}

@test "journal list accepts an explicit count" {
    cat > "$(_journal_path)" <<'EOF'
2026-04-20 08:00:00|Entry one
2026-04-21 08:00:00|Entry two
2026-04-22 08:00:00|Entry three
EOF

    run bash "$BATS_TEST_DIRNAME/../scripts/journal.sh" list 2
    [ "$status" -eq 0 ]
    [[ "$output" == *"1. 2026-04-22 08:00:00|Entry three"* ]]
    [[ "$output" == *"2. 2026-04-21 08:00:00|Entry two"* ]]
    [[ "$output" != *"Entry one"* ]]
}

@test "journal all prints all entries in newest-first order" {
    cat > "$(_journal_path)" <<'EOF'
2026-04-20 08:00:00|Entry one
2026-04-21 08:00:00|Entry two
2026-04-22 08:00:00|Entry three
EOF

    run bash "$BATS_TEST_DIRNAME/../scripts/journal.sh" all
    [ "$status" -eq 0 ]
    [[ "$output" == *"1. 2026-04-22 08:00:00|Entry three"* ]]
    [[ "$output" == *"3. 2026-04-20 08:00:00|Entry one"* ]]
}

@test "journal rel shows entries related to the current focus" {
    cat > "$(_journal_path)" <<'EOF'
2026-04-20 08:00:00|Reviewed strategy memo outline for the dashboard
2026-04-21 08:00:00|Went for a walk
2026-04-22 08:00:00|Drafted the strategic dashboard narrative
EOF
    echo "Strategy dashboard memo" > "$(_focus_path)"

    run bash "$BATS_TEST_DIRNAME/../scripts/journal.sh" rel
    [ "$status" -eq 0 ]
    [[ "$output" == *"Journal Entries Related To Current Focus"* ]]
    [[ "$output" == *"Drafted the strategic dashboard narrative"* ]]
    [[ "$output" == *"Reviewed strategy memo outline for the dashboard"* ]]
    [[ "$output" != *"Went for a walk"* ]]
}

@test "journal edit updates a recent entry by recent index" {
    cat > "$(_journal_path)" <<'EOF'
2026-04-21 08:00:00|Older entry
2026-04-22 08:00:00|Latest entry
EOF

    run bash "$BATS_TEST_DIRNAME/../scripts/journal.sh" edit 1 "Updated latest entry"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Updated journal entry 1."* ]]

    run bash "$BATS_TEST_DIRNAME/../scripts/journal.sh" list 2
    [ "$status" -eq 0 ]
    [[ "$output" == *"1. 2026-04-22 08:00:00|Updated latest entry"* ]]
    [[ "$output" == *"2. 2026-04-21 08:00:00|Older entry"* ]]
}

@test "journal rm removes a recent entry by recent index" {
    cat > "$(_journal_path)" <<'EOF'
2026-04-21 08:00:00|Older entry
2026-04-22 08:00:00|Latest entry
EOF

    run bash "$BATS_TEST_DIRNAME/../scripts/journal.sh" rm 1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed journal entry 1."* ]]

    run bash "$BATS_TEST_DIRNAME/../scripts/journal.sh" all
    [ "$status" -eq 0 ]
    [[ "$output" == *"Older entry"* ]]
    [[ "$output" != *"Latest entry"* ]]
}
