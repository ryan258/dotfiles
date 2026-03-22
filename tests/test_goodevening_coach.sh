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
    export COACH_LOG_FILE="$DATA_DIR/coach_log.txt"
    export DOTFILES_DIR="$TEST_ROOT/dotfiles"
    export PROJECTS_DIR="$TEST_ROOT/projects"
    mkdir -p "$DATA_DIR" "$DOTFILES_DIR/scripts/lib" "$DOTFILES_DIR/bin" "$PROJECTS_DIR"

    cp "$BATS_TEST_DIRNAME/../scripts/goodevening.sh" "$DOTFILES_DIR/scripts/goodevening.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coach_ops.sh" "$DOTFILES_DIR/scripts/lib/coach_ops.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coach_metrics.sh" "$DOTFILES_DIR/scripts/lib/coach_metrics.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coach_prompts.sh" "$DOTFILES_DIR/scripts/lib/coach_prompts.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coach_scoring.sh" "$DOTFILES_DIR/scripts/lib/coach_scoring.sh"
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
Reflection Summary:
- Closed the day with one clear repo lane.
What worked:
- Focus stayed mostly inside the declared repo lane.
Off-script momentum:
- Switched contexts before closing the primary task.
What pulled you in:
- Open-ended tooling exploration after commit work.
Tomorrow lock:
- First move: start with one locked task.
- Done condition: ship one visible next step.
- Scope anchor boundary: stop side quests until the done condition.
Health lens:
- Work in two bounded blocks with a break.
Evidence used:
- focus text + commit repos + behavior digest.
OUT
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-strategy.sh"
    cat > "$DOTFILES_DIR/bin/dhp-coach.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/dhp-strategy.sh" "$@"
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-coach.sh"

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
        bash "$DOTFILES_DIR/scripts/goodevening.sh" < /dev/null

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
        bash "$DOTFILES_DIR/scripts/goodevening.sh" < /dev/null

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
    [[ "$prompt" == *"Blindspots to sleep on (1-10):"* ]]
    [[ "$prompt" == *"Tomorrow lock:"* ]]
    [[ "$prompt" == *"Health lens:"* ]]
    [[ "$prompt" == *"declared focus and non-fork GitHub evidence"* ]]
    [[ "$prompt" == *"Keep journals and todos out of the coaching verdict"* ]]
    [[ "$args" == *"--temperature"* ]]

    [[ "$output" == *"What worked:"* ]]
    [[ "$output" == *"Off-script momentum:"* ]]
    [[ "$output" == *"Tomorrow lock:"* ]]

    # Signal metadata line includes confidence and reason summary
    [[ "$output" == *"(Signal:"*" - "*")"* ]]

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
    [[ "$output" == *"Off-script momentum:"* ]]
    [[ "$output" == *"What pulled you in:"* ]]
    [[ "$output" == *"Tomorrow lock:"* ]]
    [[ "$output" == *"Evidence used:"* ]]
    [[ "$output" == *"Deterministic fallback (timeout)"* ]]
    [[ "$output" != *"top task aligned to focus"* ]]
}

@test "goodevening retries after timeout and returns AI output when retry succeeds" {
    cat > "$DOTFILES_DIR/bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
sleep 2
cat <<'OUT'
Reflection Summary:
- Retry delivered output.
What worked:
- Retry delivered output.
Off-script momentum:
- Context switching.
What pulled you in:
- Open loops.
Tomorrow lock:
- First move: resume one repo lane.
- Done condition: ship one visible next step.
- Scope anchor boundary: no side quests before the first block lands.
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
        AI_COACH_EVIDENCE_CHECK_ENABLED=false \
        AI_COACH_REQUEST_TIMEOUT_SECONDS=1 \
        AI_COACH_RETRY_ON_TIMEOUT=true \
        AI_COACH_RETRY_TIMEOUT_SECONDS=4 \
        bash -c "$DOTFILES_DIR/scripts/goodevening.sh --refresh $TEST_DAY < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Retry delivered output."* ]]
    [[ "$output" != *"Deterministic fallback (timeout)"* ]]
}

@test "goodevening replaces invented journal/task evidence with deterministic fallback when evidence check is enabled" {
    cat > "$DOTFILES_DIR/bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'OUT'
Reflection Summary:
- note
What worked:
- Task completion trend is improving and journal capture remained active.
Off-script momentum:
- Drift note.
What pulled you in:
- fog.
Tomorrow lock:
- First move: resume one repo lane.
- Done condition: ship one visible next step.
- Scope anchor boundary: no side quests before the first block lands.
Health lens:
- pace blocks.
Evidence used:
- focus text only.
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
        AI_COACH_EVIDENCE_CHECK_ENABLED=true \
        AI_COACH_REQUEST_TIMEOUT_SECONDS=5 \
        AI_COACH_RETRY_ON_TIMEOUT=false \
        bash -c "$DOTFILES_DIR/scripts/goodevening.sh --refresh $TEST_DAY < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"AI coach: rejected reflection (invented journal evidence"* ]]
    [[ "$output" == *"Deterministic fallback (AI reflection failed evidence check)"* ]]
    [[ "$output" == *"Blindspots to sleep on (1-10):"* ]]
}

@test "goodevening accepts raw AI reflection when evidence check is disabled" {
    cat > "$DOTFILES_DIR/bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'OUT'
Reflection Summary:
- note
What worked:
- Task completion trend is improving and journal capture remained active.
Off-script momentum:
- Drift note.
What pulled you in:
- fog.
Tomorrow lock:
- First move: resume one repo lane.
- Done condition: ship one visible next step.
- Scope anchor boundary: no side quests before the first block lands.
Health lens:
- pace blocks.
Evidence used:
- focus text only.
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
        AI_COACH_EVIDENCE_CHECK_ENABLED=false \
        AI_COACH_REQUEST_TIMEOUT_SECONDS=5 \
        AI_COACH_RETRY_ON_TIMEOUT=false \
        bash -c "$DOTFILES_DIR/scripts/goodevening.sh --refresh $TEST_DAY < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Task completion trend is improving and journal capture remained active."* ]]
    [[ "$output" != *"AI coach: rejected reflection"* ]]
    [[ "$output" != *"Deterministic fallback (AI reflection failed evidence check)"* ]]
}

@test "goodevening cleans noisy blindspots even when evidence check is disabled" {
    cat > "$DOTFILES_DIR/bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'OUT'
Reflection Summary:
- Closed the day with one clear repo lane.
Blindspots to sleep on (1-10):
1. dir_usage_malformed=162 means your tracking stack is unstable.
2. focus_git_status=diffuse proves the spear is broken.
3. commit_context data is absent so the pattern is unknowable.
4. High brain fog score suggests a mismatch between cognitive load and capacity.
5. Low suggestion adherence rate implies planned interventions are being ignored.
6. The afternoon slump is likely derailing any complex planning work.
7. The upward completion trend is positive but based on only one recent task.
8. The lack of commit context (0) means we cannot verify whether the work is only local.
9. Keep the repo lane visible to future you.
What worked:
- Focus stayed mostly inside the declared repo lane.
Off-script momentum:
- Switched contexts before closing the primary task.
What pulled you in:
- Open-ended tooling exploration after commit work.
Tomorrow lock:
- First move: start with one locked task.
- Done condition: ship one visible next step.
- Scope anchor boundary: stop side quests until the done condition.
Health lens:
- Work in two bounded blocks with a break.
Evidence used:
- focus text + commit repos + behavior digest.
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
        AI_COACH_EVIDENCE_CHECK_ENABLED=false \
        AI_COACH_REQUEST_TIMEOUT_SECONDS=5 \
        AI_COACH_RETRY_ON_TIMEOUT=false \
        bash -c "$DOTFILES_DIR/scripts/goodevening.sh --refresh $TEST_DAY < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Blindspots to sleep on (1-10):"* ]]
    [[ "$output" == *"Keep the repo lane visible to future you."* ]]
    [[ "$output" != *"dir_usage_malformed=162"* ]]
    [[ "$output" != *"focus_git_status=diffuse proves"* ]]
    [[ "$output" != *"commit_context data is absent"* ]]
    [[ "$output" != *"High brain fog score"* ]]
    [[ "$output" != *"Low suggestion adherence rate"* ]]
    [[ "$output" != *"afternoon slump is likely derailing"* ]]
    [[ "$output" != *"upward completion trend"* ]]
    [[ "$output" != *"lack of commit context (0)"* ]]
    [[ "$output" != *"cannot verify whether the work is only local"* ]]
}
