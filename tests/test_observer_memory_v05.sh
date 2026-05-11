#!/usr/bin/env bats

# test_observer_memory_v05.sh - Bats coverage for V0.5 memory compiler.

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"

setup() {
    setup_test_environment
    OBSERVER_SCRIPT="$BATS_TEST_DIRNAME/../scripts/observer.sh"
    export OBSIDIAN_VAULT="$TEST_DIR/vault"
}

teardown() {
    teardown_test_environment
}

@test "observer init-vault creates V0.5 memory structure" {
    run "$OBSERVER_SCRIPT" init-vault
    [ "$status" -eq 0 ]
    [ -d "$OBSIDIAN_VAULT/raw/memory" ]
    [ -d "$OBSIDIAN_VAULT/wiki/memory" ]
    [ -f "$OBSIDIAN_VAULT/maps/memory-index.md" ]
}

@test "observer ensure-daily adds codex-owned memory block" {
    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-11
    [ "$status" -eq 0 ]
    grep -q "<!-- codex:start memory -->" "$OBSIDIAN_VAULT/daily/2026-05-11.md"
    grep -q "<!-- codex:end memory -->" "$OBSIDIAN_VAULT/daily/2026-05-11.md"
}

@test "memory-capture writes raw memory from stdin" {
    run bash -c "printf '%s\n' 'Remember raw to wiki promotion.' | '$OBSERVER_SCRIPT' memory-capture --date 2026-05-11 --title 'Raw To Wiki Promotion' --source-kind conversation --trigger 'User said remember this'"
    [ "$status" -eq 0 ]
    raw_path="$output"
    [ -f "$raw_path" ]
    grep -q "type: memory-raw" "$raw_path"
    grep -q "source_kind: conversation" "$raw_path"
    grep -q "Remember raw to wiki promotion." "$raw_path"
}

@test "memory-note creates durable memory note and updates daily/index" {
    run "$OBSERVER_SCRIPT" memory-capture \
        --date 2026-05-11 \
        --title "Observer Agent Architecture" \
        --content "The observer captures facts and Codex promotes durable notes."
    [ "$status" -eq 0 ]
    raw_path="$output"

    run "$OBSERVER_SCRIPT" memory-note \
        --date 2026-05-11 \
        --title "Observer Agent Architecture" \
        --raw "$raw_path" \
        --memory-type mental-model \
        --plain-english "The observer is the note-taking layer." \
        --why "It helps Ryan recover context." \
        --link "[[wiki/commands/observer|observer]]"
    [ "$status" -eq 0 ]
    note_path="$output"

    [ -f "$note_path" ]
    grep -q "type: memory" "$note_path"
    grep -q "memory_type: mental-model" "$note_path"
    grep -q "The observer is the note-taking layer." "$note_path"
    grep -q "\[\[wiki/commands/observer|observer\]\]" "$note_path"
    grep -q "Created \[\[wiki/memory/observer-agent-architecture|Observer Agent Architecture\]\]" "$OBSIDIAN_VAULT/daily/2026-05-11.md"
    grep -q "\[\[wiki/memory/observer-agent-architecture|Observer Agent Architecture\]\]" "$OBSIDIAN_VAULT/maps/memory-index.md"
}

@test "memory-note --update preserves user-owned notes block" {
    mkdir -p "$OBSIDIAN_VAULT/wiki/memory"
    cat > "$OBSIDIAN_VAULT/wiki/memory/context-recovery.md" <<'MD'
---
type: memory
status: draft
memory_type: explanation
created: 2026-05-10
updated: 2026-05-10
source_raw: ""
related:
  - "[[daily/2026-05-10]]"
---

# Context Recovery

## Plain English
<!-- codex:start plain-english -->
Old explanation.
<!-- codex:end plain-english -->

## Why Ryan Cares
<!-- codex:start why-ryan-cares -->
Old why.
<!-- codex:end why-ryan-cares -->

## Current Understanding
<!-- codex:start current-understanding -->
Old understanding.
<!-- codex:end current-understanding -->

## Links
<!-- codex:start links -->
- [[daily/2026-05-10]]
<!-- codex:end links -->

## Open Questions
<!-- codex:start open-questions -->
<!-- codex:end open-questions -->

## Notes
<!-- user:start notes -->
Do not overwrite this user note.
<!-- user:end notes -->
MD

    run "$OBSERVER_SCRIPT" memory-note \
        --date 2026-05-11 \
        --title "Context Recovery" \
        --slug context-recovery \
        --update \
        --plain-english "New explanation." \
        --open-question "How often should this be reviewed?"
    [ "$status" -eq 0 ]

    grep -q "updated: 2026-05-11" "$OBSIDIAN_VAULT/wiki/memory/context-recovery.md"
    grep -q "New explanation." "$OBSIDIAN_VAULT/wiki/memory/context-recovery.md"
    grep -q "How often should this be reviewed?" "$OBSIDIAN_VAULT/wiki/memory/context-recovery.md"
    grep -q "Do not overwrite this user note." "$OBSIDIAN_VAULT/wiki/memory/context-recovery.md"
}

