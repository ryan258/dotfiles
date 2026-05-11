#!/usr/bin/env bats

# test_observer_v0.sh - Bats coverage for the V0 Obsidian observer.

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"

setup() {
    setup_test_environment
    OBSERVER_SCRIPT="$BATS_TEST_DIRNAME/../scripts/observer.sh"
    export OBSIDIAN_VAULT="$TEST_DIR/vault"
    export OBSERVER_ENABLED=true
    export OBSERVER_CAPTURE_COMMANDS=true
}

teardown() {
    teardown_test_environment
}

_local_day_for_epoch() {
    python3 - "$1" <<'PY'
import sys
from datetime import datetime
print(datetime.fromtimestamp(float(sys.argv[1])).astimezone().date().isoformat())
PY
}

@test "observer init-vault creates V0 vault structure" {
    run "$OBSERVER_SCRIPT" init-vault
    [ "$status" -eq 0 ]
    [ -d "$OBSIDIAN_VAULT/raw/events" ]
    [ -d "$OBSIDIAN_VAULT/raw/observer-digests" ]
    [ -d "$OBSIDIAN_VAULT/daily" ]
    [ -d "$OBSIDIAN_VAULT/wiki/commands" ]
    [ -f "$OBSIDIAN_VAULT/AGENTS.md" ]
    [ -f "$OBSIDIAN_VAULT/inbox.md" ]
}

@test "observer ensure-daily creates daily note template" {
    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-11
    [ "$status" -eq 0 ]
    [ -f "$OBSIDIAN_VAULT/daily/2026-05-11.md" ]
    grep -q "<!-- observer:start commands -->" "$OBSIDIAN_VAULT/daily/2026-05-11.md"
    grep -q "<!-- observer:start promotion-candidates -->" "$OBSIDIAN_VAULT/daily/2026-05-11.md"
}

@test "observer records command events and digests command links" {
    local epoch="1778508000"
    local day
    day="$(_local_day_for_epoch "$epoch")"

    run "$OBSERVER_SCRIPT" record-command \
        --command "startday.sh" \
        --exit-code 0 \
        --cwd "$TEST_DIR" \
        --start-epoch "$epoch" \
        --end-epoch "$((epoch + 2))"
    [ "$status" -eq 0 ]

    run "$OBSERVER_SCRIPT" digest "$day"
    [ "$status" -eq 0 ]
    grep -q "\[\[wiki/commands/startday|startday\]\]" "$OBSIDIAN_VAULT/daily/$day.md"
}

@test "observer proposes promotion after command appears in three daily notes" {
    mkdir -p "$OBSIDIAN_VAULT/daily"
    for day in 2026-05-09 2026-05-10; do
        cat > "$OBSIDIAN_VAULT/daily/$day.md" <<'MD'
# Test

## Commands
<!-- observer:start commands -->
- [[wiki/commands/bash_graph|bash_graph]] - 1 run
<!-- observer:end commands -->
MD
    done

    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-11
    [ "$status" -eq 0 ]
    mkdir -p "$OBSIDIAN_VAULT/raw/events"
    cat > "$OBSIDIAN_VAULT/raw/events/2026-05-11.jsonl" <<'JSONL'
{"command":"bash_graph.sh impact startday","command_key":"bash_graph","cwd":"/tmp","duration_ms":100,"event":"command","exit_code":0,"schema":1,"ts":"2026-05-11T10:00:00-05:00"}
JSONL

    run "$OBSERVER_SCRIPT" digest 2026-05-11
    [ "$status" -eq 0 ]
    grep -q "\[candidate\] \[\[wiki/commands/bash_graph|bash_graph\]\] appeared in 3 daily notes" "$OBSIDIAN_VAULT/daily/2026-05-11.md"
}

@test "observer proposes burst candidate after five same-day command runs" {
    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-11
    [ "$status" -eq 0 ]
    mkdir -p "$OBSIDIAN_VAULT/raw/events"
    cat > "$OBSIDIAN_VAULT/raw/events/2026-05-11.jsonl" <<'JSONL'
{"command":"pytest","command_key":"pytest","cwd":"/tmp","duration_ms":100,"event":"command","exit_code":0,"schema":1,"ts":"2026-05-11T10:00:00-05:00"}
{"command":"pytest","command_key":"pytest","cwd":"/tmp","duration_ms":100,"event":"command","exit_code":0,"schema":1,"ts":"2026-05-11T10:30:00-05:00"}
{"command":"pytest","command_key":"pytest","cwd":"/tmp","duration_ms":100,"event":"command","exit_code":0,"schema":1,"ts":"2026-05-11T11:00:00-05:00"}
{"command":"pytest","command_key":"pytest","cwd":"/tmp","duration_ms":100,"event":"command","exit_code":0,"schema":1,"ts":"2026-05-11T11:30:00-05:00"}
{"command":"pytest","command_key":"pytest","cwd":"/tmp","duration_ms":100,"event":"command","exit_code":0,"schema":1,"ts":"2026-05-11T12:00:00-05:00"}
JSONL

    run "$OBSERVER_SCRIPT" digest 2026-05-11
    [ "$status" -eq 0 ]
    grep -q "\[candidate\] \[\[wiki/commands/pytest|pytest\]\] appeared 5+ times" "$OBSIDIAN_VAULT/daily/2026-05-11.md"
}

@test "observer redacts sensitive commands before writing events" {
    local epoch="1778508000"
    local day
    day="$(_local_day_for_epoch "$epoch")"

    run "$OBSERVER_SCRIPT" record-command \
        --command "curl -H 'Authorization: Bearer secret-token' https://example.com" \
        --exit-code 0 \
        --cwd "$TEST_DIR" \
        --start-epoch "$epoch" \
        --end-epoch "$epoch"
    [ "$status" -eq 0 ]
    grep -Fq '"command": "[REDACTED]"' "$OBSIDIAN_VAULT/raw/events/$day.jsonl"
    grep -Fq '"command_key": "redacted"' "$OBSIDIAN_VAULT/raw/events/$day.jsonl"
}
