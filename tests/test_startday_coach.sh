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
    mkdir -p "$DATA_DIR" "$DOTFILES_DIR/scripts/lib" "$DOTFILES_DIR/bin"

    cp "$BATS_TEST_DIRNAME/../scripts/startday.sh" "$DOTFILES_DIR/scripts/startday.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/loader.sh" "$DOTFILES_DIR/scripts/lib/loader.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coach_ops.sh" "$DOTFILES_DIR/scripts/lib/coach_ops.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coach_metrics.sh" "$DOTFILES_DIR/scripts/lib/coach_metrics.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coach_prompts.sh" "$DOTFILES_DIR/scripts/lib/coach_prompts.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coach_scoring.sh" "$DOTFILES_DIR/scripts/lib/coach_scoring.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coaching.sh" "$DOTFILES_DIR/scripts/lib/coaching.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$DOTFILES_DIR/scripts/lib/config.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/date_utils.sh" "$DOTFILES_DIR/scripts/lib/date_utils.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/health_ops.sh" "$DOTFILES_DIR/scripts/lib/health_ops.sh"
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
1. Capture the next concrete move for Ship the logo.
2. Start it in one short block.
3. Done when one concrete move is started.
Scope anchor:
- No side quests before done condition.
Operating insight (momentum + exploration):
- Working: recent delivery. Drift: context switching.
Health lens:
- Use two 45-minute blocks with a break.
OUT
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-strategy.sh"
    cat > "$DOTFILES_DIR/bin/dhp-coach.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/dhp-strategy.sh" "$@"
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-coach.sh"

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
    cat > "$DATA_DIR/daily_focus.txt" <<'EOF'
Ship the logo
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
    [[ "$prompt" == *"Wearable guidance:"* ]]
    [[ "$prompt" == *"Health lens:"* ]]
    [[ "$prompt" == *"Scope anchor:"* ]]
    [[ "$args" == *"--temperature"* ]]

    [[ "$output" == *"North Star:"* ]]
    [[ "$output" == *"Do Next (ordered 1-3):"* ]]
    [[ "$output" == *"Scope anchor:"* ]]

    # Signal metadata line includes confidence and reason summary
    [[ "$output" == *"(Signal:"*" - "*")"* ]]

    [ -f "$DATA_DIR/coach_log.txt" ]
    grep -q '^STARTDAY|' "$DATA_DIR/coach_log.txt"
}

@test "startday auto-syncs Fitbit data before the briefing when auth exists" {
    cat > "$DOTFILES_DIR/scripts/fitbit_sync.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$DATA_DIR/fitbit_sync_args_startday.txt"
EOF
    chmod +x "$DOTFILES_DIR/scripts/fitbit_sync.sh"
    printf '%s\n' '{"refresh_token":"test"}' > "$DATA_DIR/google_health_oauth.json"

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        AI_BRIEFING_ENABLED=false \
        GOOGLE_HEALTH_DEFAULT_DAYS=14 \
        bash -c "$DOTFILES_DIR/scripts/startday.sh refresh < /dev/null"

    [ "$status" -eq 0 ]
    [ -f "$DATA_DIR/fitbit_sync_args_startday.txt" ]
    [[ "$(cat "$DATA_DIR/fitbit_sync_args_startday.txt")" == "sync 14" ]]
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
    [[ "$output" == *"Capture the first concrete move for today's focus (Ship the logo)"* ]]
    [[ "$output" != *"Vectorize logo"* ]]
    [[ "$output" == *"Operating insight (momentum + exploration):"* ]]
    [[ "$output" == *"AI coaching was timeout; using deterministic fallback structure."* ]]
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
Operating insight (momentum + exploration):
- Working and drift cues.
Scope anchor:
- Hold scope.
Health lens:
- Pace work.
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

@test "startday preserves raw AI blindspots when the dispatcher returns output" {
    cat > "$DOTFILES_DIR/bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'OUT'
Briefing Summary:
- GitHub-first note.
GitHub blindspots/opportunities (1-10):
1. dir_usage_malformed=162 means the system is untrustworthy.
2. focus_git_status=diffuse proves the spear is broken.
3. commit_context is missing so there is nothing to learn.
4. Keep the repo lane visible to future you.
North Star:
- Keep momentum tied to focus.
Do Next (ordered 1-3):
1. Capture the next concrete move for Ship the logo.
2. Start it in one short block.
3. Done when one concrete move is started.
Scope anchor:
- No side quests before done condition.
Operating insight (momentum + exploration):
- Working: recent delivery. Drift: context switching.
Health lens:
- Use two 45-minute blocks with a break.
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
    [[ "$output" == *"GitHub blindspots/opportunities (1-10):"* ]]
    [[ "$output" == *"dir_usage_malformed=162 means the system is untrustworthy."* ]]
    [[ "$output" == *"focus_git_status=diffuse proves the spear is broken."* ]]
    [[ "$output" == *"commit_context is missing so there is nothing to learn."* ]]
}
