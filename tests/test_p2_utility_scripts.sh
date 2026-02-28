#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment

    export DOTFILES_DIR
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

    mkdir -p "$DOTFILES_DATA_DIR"
    touch "$DOTFILES_DATA_DIR/todo.txt"
    touch "$DOTFILES_DATA_DIR/todo_done.txt"
    touch "$DOTFILES_DATA_DIR/journal.txt"
    touch "$DOTFILES_DATA_DIR/health.txt"
    touch "$DOTFILES_DATA_DIR/dir_bookmarks"
    touch "$DOTFILES_DATA_DIR/dir_history"
    touch "$DOTFILES_DATA_DIR/dir_usage.log"
    touch "$DOTFILES_DATA_DIR/system.log"
    touch "$DOTFILES_DATA_DIR/clipboard_history.txt"
    chmod 600 "$DOTFILES_DATA_DIR"/* || true
}

teardown() {
    teardown_test_environment
}

@test "focus.sh supports set/show/done flow" {
    run "$DOTFILES_DIR/scripts/focus.sh" set "Finish daily plan"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Focus set"* ]]

    run "$DOTFILES_DIR/scripts/focus.sh" show
    [ "$status" -eq 0 ]
    [[ "$output" == *"Finish daily plan"* ]]

    run "$DOTFILES_DIR/scripts/focus.sh" done
    [ "$status" -eq 0 ]
    [[ "$output" == *"Focus completed"* ]]
}

@test "status.sh runs non-interactively without crashing" {
    run bash -c "$DOTFILES_DIR/scripts/status.sh < /dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" == *"TODAY'S FOCUS"* ]]
    [[ "$output" == *"TASKS"* ]]
}

@test "week_in_review.sh handles empty data without strict-mode exit" {
    run "$DOTFILES_DIR/scripts/week_in_review.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Your Week in Review"* ]]
}

@test "backup_data.sh creates a local archive in configured backup dir" {
    echo "test task" > "$DOTFILES_DATA_DIR/todo.txt"
    export DOTFILES_BACKUP_DIR="$TEST_DIR/backups"

    run "$DOTFILES_DIR/scripts/backup_data.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Local backup created"* ]]

    run find "$DOTFILES_BACKUP_DIR" -type f -name "dotfiles-data-backup-*.tar.gz"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "dev_shortcuts.sh json subcommand fails clearly for missing file" {
    run "$DOTFILES_DIR/scripts/dev_shortcuts.sh" json "$TEST_DIR/missing.json"
    [ "$status" -eq 3 ]
    [[ "$output" == *"JSON file not found"* ]]
}

@test "schedule.sh returns invalid-args when called without time" {
    run "$DOTFILES_DIR/scripts/schedule.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Usage: schedule.sh"* ]]
}

@test "logs.sh rejects unknown command with invalid-args status" {
    run "$DOTFILES_DIR/scripts/logs.sh" invalid
    [ "$status" -eq 2 ]
    [[ "$output" == *"Unknown command"* ]]
}

@test "network_info.sh rejects unknown command with invalid-args status" {
    run "$DOTFILES_DIR/scripts/network_info.sh" invalid
    [ "$status" -eq 2 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "clipboard_manager.sh requires mode argument" {
    run "$DOTFILES_DIR/scripts/clipboard_manager.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "clipboard_manager.sh load returns file-not-found for unknown clip" {
    run "$DOTFILES_DIR/scripts/clipboard_manager.sh" load "missing-clip-name"
    [ "$status" -eq 3 ]
    [[ "$output" == *"not found"* ]]
}

@test "clipboard_manager.sh load returns service-error when pbcopy fails" {
    cat > "$DOTFILES_DATA_DIR/clipboard_history.txt" <<'EOF'
2026-02-12 10:00:00|known-clip|hello world
EOF
    chmod 600 "$DOTFILES_DATA_DIR/clipboard_history.txt"

    local fake_bin="$TEST_DIR/fake-bin"
    mkdir -p "$fake_bin"
    cat > "$fake_bin/pbcopy" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$fake_bin/pbcopy"

    run env PATH="$fake_bin:$PATH" "$DOTFILES_DIR/scripts/clipboard_manager.sh" load "known-clip"
    [ "$status" -eq 5 ]
    [[ "$output" == *"Failed to load clip"* ]]
}

@test "dump.sh completes safely when editor writes no content" {
    export EDITOR=true
    run "$DOTFILES_DIR/scripts/dump.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing saved"* ]]
}

@test "data_validate.sh help returns success" {
    run "$DOTFILES_DIR/scripts/data_validate.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "health.sh list does not report no-appointments when appointments exist" {
    local today
    local appt_time
    today="$(date '+%Y-%m-%d')"
    appt_time="$today 10:30"
    printf 'APPT|%s|Doctor visit\n' "$appt_time" > "$DOTFILES_DATA_DIR/health.txt"

    run "$DOTFILES_DIR/scripts/health.sh" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"Doctor visit"* ]]
    [[ "$output" != *"(No appointments tracked)"* ]]
}

@test "review_clutter.sh defaults to skip in non-interactive sessions" {
    mkdir -p "$HOME/Desktop" "$HOME/Downloads" "$HOME/Documents/Archives"
    touch "$HOME/Desktop/old.txt"
    touch -t 202001010101 "$HOME/Desktop/old.txt"

    run "$DOTFILES_DIR/scripts/review_clutter.sh" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Non-interactive session detected. Skipping by default."* ]]
}

@test "take_a_break.sh prevents overlapping timers" {
    local fake_bin="$TEST_DIR/fake-bin"
    mkdir -p "$fake_bin"

    cat > "$fake_bin/osascript" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$fake_bin/osascript"

    cat > "$fake_bin/sleep" <<'EOF'
#!/usr/bin/env bash
if [[ -n "${BREAK_TIMER_TEST_BLOCK_FILE:-}" ]]; then
    while [[ ! -f "$BREAK_TIMER_TEST_BLOCK_FILE" ]]; do
        /bin/sleep 0.1
    done
fi
exit 0
EOF
    chmod +x "$fake_bin/sleep"

    local release_file="$TEST_DIR/release_break_timer"
    local first_out="$TEST_DIR/first_break.out"

    env PATH="$fake_bin:$PATH" BREAK_TIMER_TEST_BLOCK_FILE="$release_file" \
        "$DOTFILES_DIR/scripts/take_a_break.sh" 1 >"$first_out" 2>&1 &
    local first_pid=$!

    local lock_file="$DOTFILES_DATA_DIR/.take_a_break.lock/pid"
    local attempts=0
    while [[ ! -f "$lock_file" && "$attempts" -lt 50 ]]; do
        /bin/sleep 0.1
        attempts=$((attempts + 1))
    done
    [ -f "$lock_file" ]

    run env PATH="$fake_bin:$PATH" "$DOTFILES_DIR/scripts/take_a_break.sh" 1
    [ "$status" -eq 1 ]
    [[ "$output" == *"already running"* ]]

    touch "$release_file"
    local wait_status=0
    wait "$first_pid" || wait_status=$?
    [ "$wait_status" -eq 0 ]
    [ ! -d "$DOTFILES_DATA_DIR/.take_a_break.lock" ]
}
