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
    mkdir -p "$DATA_DIR" "$DOTFILES_DIR/scripts/lib" "$DOTFILES_DIR/bin"

    cp "$BATS_TEST_DIRNAME/../scripts/startday.sh" "$DOTFILES_DIR/scripts/startday.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coach_ops.sh" "$DOTFILES_DIR/scripts/lib/coach_ops.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coaching.sh" "$DOTFILES_DIR/scripts/lib/coaching.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$DOTFILES_DIR/scripts/lib/config.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/date_utils.sh" "$DOTFILES_DIR/scripts/lib/date_utils.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/common.sh" "$DOTFILES_DIR/scripts/lib/common.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/file_ops.sh" "$DOTFILES_DIR/scripts/lib/file_ops.sh"
    chmod +x "$DOTFILES_DIR/scripts/startday.sh"

    cat > "$DOTFILES_DIR/bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$DATA_DIR/strategy_args_startday.txt"
cat > "$DATA_DIR/strategy_prompt_startday.txt"
cat <<'OUT'
North Star:
- Keep momentum tied to focus.
Do Next (ordered 1-3):
1. Start with Vectorize logo as the first concrete task.
2. Complete second leverage task.
3. Done when top task is shipped.
Anti-tinker rule:
- No side quests before done condition.
Operating insight (working + drift risk):
- Working: recent delivery. Drift: context switching.
Health lens:
- Use two 45-minute blocks with a break.
Evidence check:
- commits + todos + journal + digest metrics.
OUT
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-strategy.sh"

    local day_minus_2
    local day_minus_1
    day_minus_2="$(shift_date -2)"
    day_minus_1="$(shift_date -1)"

    cat > "$DATA_DIR/todo.txt" <<EOF
$day_minus_2|Vectorize logo
$day_minus_1|Set LinkedIn schedule
EOF
    cat > "$DATA_DIR/todo_done.txt" <<EOF
$day_minus_1 10:00:00|Finished setup
EOF
    cat > "$DATA_DIR/journal.txt" <<EOF
$day_minus_1 08:00:00|Progress note
EOF
    cat > "$DATA_DIR/health.txt" <<EOF
ENERGY|$day_minus_1 09:00|5
FOG|$day_minus_1 09:00|4
EOF
    cat > "$DATA_DIR/spoons.txt" <<EOF
BUDGET|$day_minus_1|7
SPEND|$day_minus_1|12:00|3|deep-work|4
EOF
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "startday coaching prompt includes digest, mode, and health lens" {
    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        AI_BRIEFING_ENABLED=true \
        AI_COACH_LOG_ENABLED=true \
        AI_COACH_MODE_DEFAULT=LOCKED \
        bash -c "$DOTFILES_DIR/scripts/startday.sh refresh < /dev/null"

    [ "$status" -eq 0 ]
    [ -f "$DATA_DIR/strategy_prompt_startday.txt" ]
    [ -f "$DATA_DIR/strategy_args_startday.txt" ]

    prompt="$(cat "$DATA_DIR/strategy_prompt_startday.txt")"
    args="$(cat "$DATA_DIR/strategy_args_startday.txt")"

    [[ "$prompt" == *"Coach mode for today:"* ]]
    [[ "$prompt" == *"Behavior digest:"* ]]
    [[ "$prompt" == *"Health lens:"* ]]
    [[ "$prompt" == *"Anti-tinker rule:"* ]]
    [[ "$args" == *"--temperature"* ]]

    [[ "$output" == *"North Star:"* ]]
    [[ "$output" == *"Do Next (ordered 1-3):"* ]]
    [[ "$output" == *"Anti-tinker rule:"* ]]

    [ -f "$DATA_DIR/coach_log.txt" ]
    grep -q '^STARTDAY|' "$DATA_DIR/coach_log.txt"
}

@test "startday uses deterministic fallback when strategy call times out" {
    cat > "$DOTFILES_DIR/bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
sleep 3
echo "late response"
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-strategy.sh"

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        AI_BRIEFING_ENABLED=true \
        AI_COACH_LOG_ENABLED=true \
        AI_COACH_MODE_DEFAULT=LOCKED \
        AI_COACH_REQUEST_TIMEOUT_SECONDS=1 \
        AI_COACH_RETRY_ON_TIMEOUT=false \
        bash -c "$DOTFILES_DIR/scripts/startday.sh refresh < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"North Star:"* ]]
    [[ "$output" == *"Do Next (ordered 1-3):"* ]]
    [[ "$output" == *"starting: Vectorize logo"* ]]
    [[ "$output" != *"starting: -- Top 3 Tasks ---"* ]]
    [[ "$output" == *"Operating insight (working + drift risk):"* ]]
    [[ "$output" == *"Evidence check:"* ]]
    [[ "$output" == *"Deterministic fallback (timeout)"* ]]
}

@test "startday retries after timeout and returns AI output when retry succeeds" {
    cat > "$DOTFILES_DIR/bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
sleep 2
cat <<'OUT'
North Star:
- Return AI response after retry.
Do Next (ordered 1-3):
1. Start with Vectorize logo.
2. Execute second action.
3. Done condition captured.
Operating insight (working + drift risk):
- Working and drift cues.
Anti-tinker rule:
- Hold scope.
Health lens:
- Pace work.
Evidence check:
- retry-path test.
OUT
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-strategy.sh"

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        AI_BRIEFING_ENABLED=true \
        AI_COACH_LOG_ENABLED=true \
        AI_COACH_MODE_DEFAULT=LOCKED \
        AI_COACH_REQUEST_TIMEOUT_SECONDS=1 \
        AI_COACH_RETRY_ON_TIMEOUT=true \
        AI_COACH_RETRY_TIMEOUT_SECONDS=4 \
        bash -c "$DOTFILES_DIR/scripts/startday.sh refresh < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Return AI response after retry."* ]]
    [[ "$output" != *"Deterministic fallback (timeout)"* ]]
}

@test "startday replaces ungrounded AI Do Next with deterministic fallback" {
    cat > "$DOTFILES_DIR/bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'OUT'
North Star:
- Launch a mini coach project.
Do Next (ordered 1-3):
1. Open todo list and align focus.
2. Create a folder named Coach and scaffold an endpoint.
3. Verify the endpoint response.
Operating insight (working + drift risk):
- Working and drift cues.
Anti-tinker rule:
- Avoid side quests.
Health lens:
- Pace work.
Evidence check:
- context cues.
OUT
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-strategy.sh"

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        AI_BRIEFING_ENABLED=true \
        AI_COACH_LOG_ENABLED=true \
        AI_COACH_MODE_DEFAULT=LOCKED \
        AI_COACH_REQUEST_TIMEOUT_SECONDS=5 \
        AI_COACH_RETRY_ON_TIMEOUT=false \
        bash -c "$DOTFILES_DIR/scripts/startday.sh refresh < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deterministic fallback (ungrounded-actions)"* ]]
    [[ "$output" != *"Create a folder named Coach"* ]]
}
