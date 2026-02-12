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
    export DOTFILES_DIR="$TEST_ROOT/dotfiles"
    export PROJECTS_DIR="$TEST_ROOT/projects"
    mkdir -p "$DATA_DIR" "$DOTFILES_DIR/scripts/lib" "$DOTFILES_DIR/bin" "$PROJECTS_DIR"

    cp "$BATS_TEST_DIRNAME/../scripts/goodevening.sh" "$DOTFILES_DIR/scripts/goodevening.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coach_ops.sh" "$DOTFILES_DIR/scripts/lib/coach_ops.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coaching.sh" "$DOTFILES_DIR/scripts/lib/coaching.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$DOTFILES_DIR/scripts/lib/config.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/date_utils.sh" "$DOTFILES_DIR/scripts/lib/date_utils.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/common.sh" "$DOTFILES_DIR/scripts/lib/common.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/file_ops.sh" "$DOTFILES_DIR/scripts/lib/file_ops.sh"
    chmod +x "$DOTFILES_DIR/scripts/goodevening.sh"

    cat > "$DOTFILES_DIR/scripts/data_validate.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$DOTFILES_DIR/scripts/data_validate.sh"

    cat > "$DOTFILES_DIR/scripts/backup_data.sh" <<'EOF'
#!/usr/bin/env bash
echo "backup ok"
exit 0
EOF
    chmod +x "$DOTFILES_DIR/scripts/backup_data.sh"

    cat > "$DOTFILES_DIR/bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$DATA_DIR/strategy_args_goodevening.txt"
cat > "$DATA_DIR/strategy_prompt_goodevening.txt"
cat <<'OUT'
What worked:
- Finished one concrete deliverable and logged context.
Where drift happened:
- Switched contexts before closing the primary task.
Likely trigger:
- Open-ended tooling exploration after commit work.
Tomorrow lock:
- Start with one locked task and stop side quests until done condition.
Health lens:
- Work in two bounded blocks with a break.
Evidence used:
- done tasks + journal + commits + behavior digest.
OUT
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-strategy.sh"

    export TEST_DAY
    TEST_DAY="$(shift_date -1)"

    cat > "$DATA_DIR/todo_done.txt" <<EOF
$TEST_DAY 09:00:00|Completed primary task
EOF
    cat > "$DATA_DIR/journal.txt" <<EOF
$TEST_DAY 10:00:00|Kept focus for first block
EOF
    cat > "$DATA_DIR/daily_focus.txt" <<'EOF'
Ship one high-signal automation
EOF
    cat > "$DATA_DIR/health.txt" <<EOF
ENERGY|$TEST_DAY 09:00|5
FOG|$TEST_DAY 09:00|5
EOF
    cat > "$DATA_DIR/spoons.txt" <<EOF
BUDGET|$TEST_DAY|7
SPEND|$TEST_DAY|12:00|3|work|4
EOF
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "goodevening falls back to system date when startday marker is missing" {
    rm -f "$DATA_DIR/current_day"
    expected_today="$(date +%Y-%m-%d)"

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        AI_REFLECTION_ENABLED=false \
        bash "$DOTFILES_DIR/scripts/goodevening.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Evening Close-Out for $expected_today"* ]]
    grep -q "startday marker missing; using system date $expected_today" "$DATA_DIR/system.log"
}

@test "goodevening ignores stale startday marker older than 24 hours" {
    printf '%s\n' "$(shift_date -30)" > "$DATA_DIR/current_day"
    python3 - "$DATA_DIR/current_day" <<'PY'
import os
import sys
import time

stale_epoch = int(time.time()) - (3 * 24 * 60 * 60)
os.utime(sys.argv[1], (stale_epoch, stale_epoch))
PY
    expected_today="$(date +%Y-%m-%d)"

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        AI_REFLECTION_ENABLED=false \
        bash "$DOTFILES_DIR/scripts/goodevening.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Evening Close-Out for $expected_today"* ]]
    grep -q "stale current_day marker" "$DATA_DIR/system.log"
}

@test "goodevening reflection prompt uses reflective schema" {
    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        AI_REFLECTION_ENABLED=true \
        AI_COACH_LOG_ENABLED=true \
        AI_COACH_MODE_DEFAULT=LOCKED \
        bash -c "$DOTFILES_DIR/scripts/goodevening.sh --refresh $TEST_DAY < /dev/null"

    [ "$status" -eq 0 ]
    [ -f "$DATA_DIR/strategy_prompt_goodevening.txt" ]
    [ -f "$DATA_DIR/strategy_args_goodevening.txt" ]

    prompt="$(cat "$DATA_DIR/strategy_prompt_goodevening.txt")"
    args="$(cat "$DATA_DIR/strategy_args_goodevening.txt")"

    [[ "$prompt" == *"Coach mode used today:"* ]]
    [[ "$prompt" == *"Behavior digest:"* ]]
    [[ "$prompt" == *"Tomorrow lock:"* ]]
    [[ "$prompt" == *"Health lens:"* ]]
    [[ "$args" == *"--temperature"* ]]

    [[ "$output" == *"What worked:"* ]]
    [[ "$output" == *"Where drift happened:"* ]]
    [[ "$output" == *"Tomorrow lock:"* ]]

    [ -f "$DATA_DIR/coach_log.txt" ]
    grep -q '^GOODEVENING|' "$DATA_DIR/coach_log.txt"
}

@test "goodevening uses deterministic fallback when strategy call times out" {
    cat > "$DOTFILES_DIR/bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
sleep 3
echo "late reflection"
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-strategy.sh"

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        AI_REFLECTION_ENABLED=true \
        AI_COACH_LOG_ENABLED=true \
        AI_COACH_MODE_DEFAULT=LOCKED \
        AI_COACH_REQUEST_TIMEOUT_SECONDS=1 \
        AI_COACH_RETRY_ON_TIMEOUT=false \
        bash -c "$DOTFILES_DIR/scripts/goodevening.sh --refresh $TEST_DAY < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"What worked:"* ]]
    [[ "$output" == *"Where drift happened:"* ]]
    [[ "$output" == *"Likely trigger:"* ]]
    [[ "$output" == *"Tomorrow lock:"* ]]
    [[ "$output" == *"Evidence used:"* ]]
    [[ "$output" == *"Deterministic fallback (timeout)"* ]]
}

@test "goodevening retries after timeout and returns AI output when retry succeeds" {
    cat > "$DOTFILES_DIR/bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
sleep 2
cat <<'OUT'
What worked:
- Retry delivered output.
Where drift happened:
- Context switching.
Likely trigger:
- Open loops.
Tomorrow lock:
- First move + done condition + boundary.
Health lens:
- Pace blocks.
Evidence used:
- retry-path test.
OUT
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-strategy.sh"

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        AI_REFLECTION_ENABLED=true \
        AI_COACH_LOG_ENABLED=true \
        AI_COACH_MODE_DEFAULT=LOCKED \
        AI_COACH_REQUEST_TIMEOUT_SECONDS=1 \
        AI_COACH_RETRY_ON_TIMEOUT=true \
        AI_COACH_RETRY_TIMEOUT_SECONDS=4 \
        bash -c "$DOTFILES_DIR/scripts/goodevening.sh --refresh $TEST_DAY < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Retry delivered output."* ]]
    [[ "$output" != *"Deterministic fallback (timeout)"* ]]
}
