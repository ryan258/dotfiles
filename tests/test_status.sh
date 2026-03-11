#!/usr/bin/env bats

load helpers/test_helpers.sh
load helpers/assertions.sh

shift_date() {
    python3 - "$1" <<'PY'
import sys
from datetime import date, timedelta

offset = int(sys.argv[1])
print((date.today() + timedelta(days=offset)).strftime("%Y-%m-%d"))
PY
}

setup() {
    export TEST_ROOT
    TEST_ROOT="$(mktemp -d)"
    export HOME="$TEST_ROOT/home"
    export DATA_DIR="$HOME/.config/dotfiles-data"
    export COACH_MODE_FILE="$DATA_DIR/coach_mode.txt"
    export DOTFILES_DIR="$TEST_ROOT/dotfiles"
    export PROJECTS_DIR="$TEST_ROOT/projects"
    mkdir -p "$DATA_DIR" "$DOTFILES_DIR/scripts/lib" "$PROJECTS_DIR"

    # Copy core libraries
    for lib in common.sh config.sh date_utils.sh file_ops.sh spoon_budget.sh health_ops.sh github_ops.sh coach_metrics.sh; do
        if [ -f "$BATS_TEST_DIRNAME/../scripts/lib/$lib" ]; then
            cp "$BATS_TEST_DIRNAME/../scripts/lib/$lib" "$DOTFILES_DIR/scripts/lib/$lib"
        fi
    done
    cp "$BATS_TEST_DIRNAME/../scripts/status.sh" "$DOTFILES_DIR/scripts/status.sh"
    chmod +x "$DOTFILES_DIR/scripts/status.sh"

    # Minimal todo.sh stub
    cat > "$DOTFILES_DIR/scripts/todo.sh" <<'STUB'
#!/usr/bin/env bash
echo "  1. Sample task"
STUB
    chmod +x "$DOTFILES_DIR/scripts/todo.sh"

    cat > "$DOTFILES_DIR/scripts/github_helper.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    list_commits_for_date)
        if [ -n "${GITHUB_COMMITS_FIXTURE:-}" ] && [ -f "$GITHUB_COMMITS_FIXTURE" ]; then
            cat "$GITHUB_COMMITS_FIXTURE"
        fi
        ;;
    list_repos|list_user_events)
        echo "[]"
        ;;
esac
STUB
    chmod +x "$DOTFILES_DIR/scripts/github_helper.sh"

    export TODAY
    TODAY="$(date +%Y-%m-%d)"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

_run_status() {
    env \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        "$@" \
        bash "$DOTFILES_DIR/scripts/status.sh" < /dev/null
}

# ─── Core sections ────────────────────────────────────────────────────────

@test "status.sh exits 0 and shows expected section headers" {
    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"TODAY'S FOCUS:"* ]]
    [[ "$output" == *"DAILY CONTEXT:"* ]]
    [[ "$output" == *"WHERE YOU ARE:"* ]]
    [[ "$output" == *"TODAY'S JOURNAL"* ]]
    [[ "$output" == *"TASKS:"* ]]
}

@test "status.sh shows focus when focus file exists" {
    echo "Ship the logo" > "$DATA_DIR/daily_focus.txt"

    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"Ship the logo"* ]]
}

@test "status.sh shows no-focus placeholder when focus file is missing" {
    rm -f "$DATA_DIR/daily_focus.txt"

    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"(No focus set)"* ]]
}

# ─── DAILY CONTEXT section ────────────────────────────────────────────────

@test "status.sh DAILY CONTEXT shows mode from coach_mode file" {
    echo "${TODAY}|OVERRIDE" > "$COACH_MODE_FILE"

    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode: OVERRIDE"* ]]
}

@test "status.sh DAILY CONTEXT defaults mode to LOCKED when no mode file exists" {
    rm -f "$COACH_MODE_FILE"

    run _run_status AI_COACH_MODE_DEFAULT=LOCKED

    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode: LOCKED"* ]]
}

@test "status.sh DAILY CONTEXT defaults mode when mode file has no entry for today" {
    local yesterday
    yesterday="$(shift_date -1)"
    echo "${yesterday}|RECOVERY" > "$COACH_MODE_FILE"

    run _run_status AI_COACH_MODE_DEFAULT=LOCKED

    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode: LOCKED"* ]]
}

@test "status.sh DAILY CONTEXT shows spoon budget and remaining" {
    cat > "$DATA_DIR/spoons.txt" <<EOF
BUDGET|${TODAY}|8
SPEND|${TODAY}|10:00|3|deep-work|5
EOF

    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"Spoons: 5/8 remaining"* ]]
}

@test "status.sh DAILY CONTEXT shows full budget when no spoons spent" {
    cat > "$DATA_DIR/spoons.txt" <<EOF
BUDGET|${TODAY}|12
EOF

    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"Spoons: 12/12 remaining"* ]]
}

@test "status.sh DAILY CONTEXT shows ? remaining when no spoon log exists" {
    rm -f "$DATA_DIR/spoons.txt"

    run _run_status DEFAULT_DAILY_SPOONS=10

    [ "$status" -eq 0 ]
    [[ "$output" == *"Spoons: ?/10 remaining"* ]]
}

@test "status.sh DAILY CONTEXT shows focus and spear alignment from Git evidence" {
    echo "logo" > "$DATA_DIR/daily_focus.txt"
    cat > "$DATA_DIR/github_commits.txt" <<'EOF'
dotfiles|abc1234|ship logo
EOF

    run _run_status GITHUB_COMMITS_FIXTURE="$DATA_DIR/github_commits.txt"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Focus: logo"* ]]
    [[ "$output" == *"Spear alignment: aligned via dotfiles (100% commit coherence; 1 repo active)"* ]]
}

# ─── Journal section ─────────────────────────────────────────────────────

@test "status.sh shows today's journal entries" {
    cat > "$DATA_DIR/journal.txt" <<EOF
${TODAY} 09:00:00|Morning reflection on goals
${TODAY} 14:00:00|Afternoon progress note
EOF

    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"Morning reflection on goals"* ]]
    [[ "$output" == *"Afternoon progress note"* ]]
}

@test "status.sh shows placeholder when no journal entries for today" {
    local yesterday
    yesterday="$(shift_date -1)"
    cat > "$DATA_DIR/journal.txt" <<EOF
${yesterday} 09:00:00|Yesterday entry
EOF

    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"(No entries for today yet)"* ]]
}

# ─── Last journal entry ──────────────────────────────────────────────────

@test "status.sh shows last journal entry in WHERE YOU ARE section" {
    cat > "$DATA_DIR/journal.txt" <<EOF
${TODAY} 08:00:00|First entry
${TODAY} 16:00:00|Last entry of the day
EOF

    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"Last journal entry:"*"Last entry of the day"* ]]
}

# ─── Section ordering ────────────────────────────────────────────────────

@test "status.sh DAILY CONTEXT appears between FOCUS and WHERE YOU ARE" {
    echo "My focus" > "$DATA_DIR/daily_focus.txt"

    run _run_status

    [ "$status" -eq 0 ]

    # Extract line numbers for section headers
    focus_line=$(echo "$output" | grep -n "TODAY'S FOCUS:" | head -1 | cut -d: -f1)
    context_line=$(echo "$output" | grep -n "DAILY CONTEXT:" | head -1 | cut -d: -f1)
    where_line=$(echo "$output" | grep -n "WHERE YOU ARE:" | head -1 | cut -d: -f1)

    [ -n "$focus_line" ]
    [ -n "$context_line" ]
    [ -n "$where_line" ]
    [ "$focus_line" -lt "$context_line" ]
    [ "$context_line" -lt "$where_line" ]
}
