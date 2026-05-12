#!/usr/bin/env bats

# test_observer_v1.sh - Bats coverage for V1 open loops and explorations.

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    OBSERVER_SCRIPT="$BATS_TEST_DIRNAME/../scripts/observer.sh"
    export OBSIDIAN_VAULT="$TEST_DIR/vault"
    mkdir -p "$TEST_DIR/dotfiles"
}

teardown() {
    teardown_test_environment
}

@test "observer init-vault creates V1 structure and daily sections" {
    run "$OBSERVER_SCRIPT" init-vault
    [ "$status" -eq 0 ]
    [ -d "$OBSIDIAN_VAULT/raw/open-loops" ]
    [ -d "$OBSIDIAN_VAULT/raw/explorations" ]
    [ -d "$OBSIDIAN_VAULT/wiki/open-loops" ]
    grep -q "## Open Loops" "$OBSIDIAN_VAULT/AGENTS.md"
    grep -q "## Explorations" "$OBSIDIAN_VAULT/AGENTS.md"

    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-11
    [ "$status" -eq 0 ]
    grep -q "<!-- observer:start open-loops -->" "$OBSIDIAN_VAULT/daily/2026-05-11.md"
    grep -q "<!-- observer:start explorations -->" "$OBSIDIAN_VAULT/daily/2026-05-11.md"
}

@test "observer dedupes pytest failure variants into one raw open loop" {
    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-11
    [ "$status" -eq 0 ]
    mkdir -p "$OBSIDIAN_VAULT/raw/events"
    cat > "$OBSIDIAN_VAULT/raw/events/2026-05-11.jsonl" <<JSONL
{"command":"uv run pytest -q","command_key":"uv","cwd":"$TEST_DIR/dotfiles","duration_ms":100,"event":"command","exit_code":1,"schema":1,"ts":"2026-05-11T10:00:00-05:00"}
{"command":"uv run pytest tests/test_observer.py -v","command_key":"uv","cwd":"$TEST_DIR/dotfiles","duration_ms":100,"event":"command","exit_code":1,"schema":1,"ts":"2026-05-11T11:00:00-05:00"}
JSONL

    run "$OBSERVER_SCRIPT" digest 2026-05-11
    [ "$status" -eq 0 ]
    raw="$OBSIDIAN_VAULT/raw/open-loops/dotfiles--command-failure--uv-run-pytest.jsonl"
    [ -f "$raw" ]
    [ "$(wc -l < "$raw" | tr -d ' ')" -eq 2 ]
    [ "$(find "$OBSIDIAN_VAULT/raw/open-loops" -type f | wc -l | tr -d ' ')" -eq 1 ]
    grep -q "dotfiles::command-failure::uv-run-pytest" "$OBSIDIAN_VAULT/daily/2026-05-11.md"
}

@test "observer keeps interpreter script paths in the loop subject" {
    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-11
    [ "$status" -eq 0 ]
    mkdir -p "$OBSIDIAN_VAULT/raw/events"
    cat > "$OBSIDIAN_VAULT/raw/events/2026-05-11.jsonl" <<JSONL
{"command":"bash scripts/health.sh","command_key":"bash","cwd":"$TEST_DIR/dotfiles","duration_ms":100,"event":"command","exit_code":1,"schema":1,"ts":"2026-05-11T10:00:00-05:00"}
{"command":"bash scripts/observer.sh","command_key":"bash","cwd":"$TEST_DIR/dotfiles","duration_ms":100,"event":"command","exit_code":1,"schema":1,"ts":"2026-05-11T11:00:00-05:00"}
{"command":"python tools/cleanup.py --dry-run","command_key":"python","cwd":"$TEST_DIR/dotfiles","duration_ms":100,"event":"command","exit_code":1,"schema":1,"ts":"2026-05-11T12:00:00-05:00"}
JSONL

    run "$OBSERVER_SCRIPT" digest 2026-05-11
    [ "$status" -eq 0 ]
    [ -f "$OBSIDIAN_VAULT/raw/open-loops/dotfiles--command-failure--bash-scripts-health-sh.jsonl" ]
    [ -f "$OBSIDIAN_VAULT/raw/open-loops/dotfiles--command-failure--bash-scripts-observer-sh.jsonl" ]
    [ -f "$OBSIDIAN_VAULT/raw/open-loops/dotfiles--command-failure--python-tools-cleanup-py.jsonl" ]
}

@test "observer drops single-letter flag values from normalized subjects" {
    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-11
    [ "$status" -eq 0 ]
    mkdir -p "$OBSIDIAN_VAULT/raw/events"
    cat > "$OBSIDIAN_VAULT/raw/events/2026-05-11.jsonl" <<JSONL
{"command":"git commit -m \"x\"","command_key":"git","cwd":"$TEST_DIR/dotfiles","duration_ms":100,"event":"command","exit_code":1,"schema":1,"ts":"2026-05-11T10:00:00-05:00"}
JSONL

    run "$OBSERVER_SCRIPT" digest 2026-05-11
    [ "$status" -eq 0 ]
    [ -f "$OBSIDIAN_VAULT/raw/open-loops/dotfiles--command-failure--git-commit.jsonl" ]
}

@test "observer detects TODO/FIXME in modified repo files and resolves when removed" {
    repo="$TEST_DIR/todo-repo"
    mkdir -p "$repo/scripts"
    git -C "$repo" init >/dev/null
    git -C "$repo" config user.email "test@example.com"
    git -C "$repo" config user.name "Test User"
    printf '%s\n' 'echo ok' > "$repo/scripts/observer.sh"
    git -C "$repo" add scripts/observer.sh
    git -C "$repo" commit -m "init" >/dev/null
    printf '%s\n' 'echo ok' '# TODO define observer redaction tests' > "$repo/scripts/observer.sh"

    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-11
    [ "$status" -eq 0 ]
    mkdir -p "$OBSIDIAN_VAULT/raw/events"
    cat > "$OBSIDIAN_VAULT/raw/events/2026-05-11.jsonl" <<JSONL
{"command":"git status","command_key":"git","cwd":"$repo","duration_ms":100,"event":"command","exit_code":0,"schema":1,"ts":"2026-05-11T10:00:00-05:00"}
JSONL
    run "$OBSERVER_SCRIPT" digest 2026-05-11
    [ "$status" -eq 0 ]
    raw="$OBSIDIAN_VAULT/raw/open-loops/todo-repo--todo-fixme--scripts-observer-sh.jsonl"
    [ -f "$raw" ]
    grep -q "TODO/FIXME in scripts/observer.sh" "$raw"

    run "$OBSERVER_SCRIPT" open-loop-accept "todo-repo::todo-fixme::scripts-observer-sh" --date 2026-05-11
    [ "$status" -eq 0 ]
    printf '%s\n' 'echo ok' > "$repo/scripts/observer.sh"

    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-12
    [ "$status" -eq 0 ]
    cat > "$OBSIDIAN_VAULT/raw/events/2026-05-12.jsonl" <<JSONL
{"command":"git status","command_key":"git","cwd":"$repo","duration_ms":100,"event":"command","exit_code":0,"schema":1,"ts":"2026-05-12T10:00:00-05:00"}
JSONL
    run "$OBSERVER_SCRIPT" digest 2026-05-12
    [ "$status" -eq 0 ]
    grep -q '"event": "resolution-candidate"' "$raw"
    grep -q "TODO/FIXME no longer found in scripts/observer.sh" "$raw"
}

@test "observer emits resolution candidates only for accepted matching loops" {
    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-11
    [ "$status" -eq 0 ]
    mkdir -p "$OBSIDIAN_VAULT/raw/events"
    cat > "$OBSIDIAN_VAULT/raw/events/2026-05-11.jsonl" <<JSONL
{"command":"uv run pytest -q","command_key":"uv","cwd":"$TEST_DIR/dotfiles","duration_ms":100,"event":"command","exit_code":1,"schema":1,"ts":"2026-05-11T10:00:00-05:00"}
JSONL
    run "$OBSERVER_SCRIPT" digest 2026-05-11
    [ "$status" -eq 0 ]

    run "$OBSERVER_SCRIPT" open-loop-accept "dotfiles::command-failure::uv-run-pytest" --date 2026-05-11
    [ "$status" -eq 0 ]
    [ -f "$OBSIDIAN_VAULT/wiki/open-loops/dotfiles--command-failure--uv-run-pytest.md" ]

    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-12
    [ "$status" -eq 0 ]
    cat > "$OBSIDIAN_VAULT/raw/events/2026-05-12.jsonl" <<JSONL
{"command":"uv run pytest -q","command_key":"uv","cwd":"$TEST_DIR/dotfiles","duration_ms":100,"event":"command","exit_code":0,"schema":1,"ts":"2026-05-12T10:00:00-05:00"}
{"command":"bash scripts/health.sh","command_key":"bash","cwd":"$TEST_DIR/dotfiles","duration_ms":100,"event":"command","exit_code":0,"schema":1,"ts":"2026-05-12T11:00:00-05:00"}
JSONL

    run "$OBSERVER_SCRIPT" digest 2026-05-12
    [ "$status" -eq 0 ]
    grep -q '"event": "resolution-candidate"' "$OBSIDIAN_VAULT/raw/open-loops/dotfiles--command-failure--uv-run-pytest.jsonl"
    grep -q "\[resolve?\]" "$OBSIDIAN_VAULT/daily/2026-05-12.md"
    [ ! -f "$OBSIDIAN_VAULT/raw/open-loops/dotfiles--command-failure--bash-scripts-health-sh.jsonl" ]
}

@test "observer startday surfaces accepted loops including one stale loop" {
    mkdir -p "$OBSIDIAN_VAULT/wiki/open-loops" "$OBSIDIAN_VAULT/raw/open-loops"
    cat > "$OBSIDIAN_VAULT/wiki/open-loops/stale.md" <<'MD'
---
type: open-loop
status: accepted
created: 2026-05-01
updated: 2026-05-01
last_surfaced:
loop_key: dotfiles::command-failure::stale-loop
related:
  - "[[daily/2026-05-01]]"
---

# Stale Loop
MD
    cat > "$OBSIDIAN_VAULT/wiki/open-loops/fresh.md" <<'MD'
---
type: open-loop
status: surfaced
created: 2026-05-10
updated: 2026-05-10
last_surfaced:
loop_key: dotfiles::command-failure::fresh-loop
related:
  - "[[daily/2026-05-10]]"
---

# Fresh Loop
MD

    run "$OBSERVER_SCRIPT" startday 2026-05-11
    [ "$status" -eq 0 ]
    grep -q "\[surface stale\] \[\[wiki/open-loops/stale|Stale Loop\]\]" "$OBSIDIAN_VAULT/daily/2026-05-11.md"
    grep -q "\[surface\] \[\[wiki/open-loops/fresh|Fresh Loop\]\]" "$OBSIDIAN_VAULT/daily/2026-05-11.md"
}

@test "observer captures explicit user loop and exploration markers" {
    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-11
    [ "$status" -eq 0 ]
    python3 - "$OBSIDIAN_VAULT/daily/2026-05-11.md" <<'PY'
from pathlib import Path
path = Path(__import__("sys").argv[1])
text = path.read_text()
text = text.replace(
    "<!-- user:start notes -->\n<!-- user:end notes -->",
    "<!-- user:start notes -->\n- [loop] define observer redaction tests\n- [explore] sketch observer UI\n<!-- user:end notes -->",
)
path.write_text(text)
PY

    run "$OBSERVER_SCRIPT" digest 2026-05-11
    [ "$status" -eq 0 ]
    [ -f "$OBSIDIAN_VAULT/raw/open-loops/daily--user-loop--define-observer-redaction-tests.jsonl" ]
    [ -f "$OBSIDIAN_VAULT/raw/explorations/2026-05-11--daily--sketch-observer-ui.jsonl" ]
    grep -q "daily::user-loop::define-observer-redaction-tests" "$OBSIDIAN_VAULT/daily/2026-05-11.md"
    grep -q "2026-05-11::daily::sketch-observer-ui" "$OBSIDIAN_VAULT/daily/2026-05-11.md"
}

@test "observer exploration extend delays expiry rendering" {
    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-10
    [ "$status" -eq 0 ]
    python3 - "$OBSIDIAN_VAULT/daily/2026-05-10.md" <<'PY'
from pathlib import Path
path = Path(__import__("sys").argv[1])
text = path.read_text()
text = text.replace(
    "<!-- user:start notes -->\n<!-- user:end notes -->",
    "<!-- user:start notes -->\n- [explore] sketch observer UI\n<!-- user:end notes -->",
)
path.write_text(text)
PY
    run "$OBSERVER_SCRIPT" digest 2026-05-10
    [ "$status" -eq 0 ]

    run "$OBSERVER_SCRIPT" exploration-action "2026-05-10::daily::sketch-observer-ui" --action extend --date 2026-05-10 --evidence "Needs one more day"
    [ "$status" -eq 0 ]

    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-11
    [ "$status" -eq 0 ]
    run "$OBSERVER_SCRIPT" digest 2026-05-11
    [ "$status" -eq 0 ]
    grep -q "No exploration candidates" "$OBSIDIAN_VAULT/daily/2026-05-11.md"

    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-12
    [ "$status" -eq 0 ]
    run "$OBSERVER_SCRIPT" digest 2026-05-12
    [ "$status" -eq 0 ]
    grep -q "\[expired\] Sketch observer ui" "$OBSIDIAN_VAULT/daily/2026-05-12.md"
    grep -q "TTL: review within 48 hours" "$OBSIDIAN_VAULT/daily/2026-05-12.md"
}

@test "observer expires explorations and can convert one to an open loop" {
    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-10
    [ "$status" -eq 0 ]
    python3 - "$OBSIDIAN_VAULT/daily/2026-05-10.md" <<'PY'
from pathlib import Path
path = Path(__import__("sys").argv[1])
text = path.read_text()
text = text.replace(
    "<!-- user:start notes -->\n<!-- user:end notes -->",
    "<!-- user:start notes -->\n- [explore] sketch observer UI\n<!-- user:end notes -->",
)
path.write_text(text)
PY
    run "$OBSERVER_SCRIPT" digest 2026-05-10
    [ "$status" -eq 0 ]

    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-11
    [ "$status" -eq 0 ]
    run "$OBSERVER_SCRIPT" digest 2026-05-11
    [ "$status" -eq 0 ]
    grep -q "\[expired\] Sketch observer ui" "$OBSIDIAN_VAULT/daily/2026-05-11.md"

    run "$OBSERVER_SCRIPT" exploration-action "2026-05-10::daily::sketch-observer-ui" --action convert --date 2026-05-11 --evidence "Convert to follow-up"
    [ "$status" -eq 0 ]
    [ -f "$OBSIDIAN_VAULT/raw/open-loops/daily--exploration-conversion--sketch-observer-ui.jsonl" ]
}
