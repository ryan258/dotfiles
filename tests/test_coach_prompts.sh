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
    mkdir -p "$DATA_DIR" "$DOTFILES_DIR"

    export CONFIG_LIB="$BATS_TEST_DIRNAME/../scripts/lib/config.sh"
    export COMMON_LIB="$BATS_TEST_DIRNAME/../scripts/lib/common.sh"
    export DATE_LIB="$BATS_TEST_DIRNAME/../scripts/lib/date_utils.sh"
    export METRICS_LIB="$BATS_TEST_DIRNAME/../scripts/lib/coach_metrics.sh"
    export PROMPTS_LIB="$BATS_TEST_DIRNAME/../scripts/lib/coach_prompts.sh"
    export SOURCE_PREFIX="source '$CONFIG_LIB'; source '$COMMON_LIB'; source '$DATE_LIB'; source '$METRICS_LIB'; source '$PROMPTS_LIB'"

    export DAY_MINUS1
    DAY_MINUS1="$(shift_date -1)"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

# ─── coach_build_startday_prompt ──────────────────────────────────────────

@test "coach_build_startday_prompt includes all required schema sections" {
    run bash -c "$SOURCE_PREFIX; coach_build_startday_prompt \
        'Ship the logo' 'LOCKED' 'abc123 commit' 'dotfiles push' \
        'journal entry' 'yesterday journal' 'Vectorize logo' 'digest blob'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Today's focus:"* ]]
    [[ "$output" == *"Ship the logo"* ]]
    [[ "$output" == *"Coach mode for today:"* ]]
    [[ "$output" == *"LOCKED"* ]]
    [[ "$output" == *"Yesterday's commits:"* ]]
    [[ "$output" == *"Recent GitHub pushes"* ]]
    [[ "$output" == *"Recent journal entries:"* ]]
    [[ "$output" == *"Yesterday's journal entries:"* ]]
    [[ "$output" == *"Top tasks:"* ]]
    [[ "$output" == *"Behavior digest:"* ]]
    [[ "$output" == *"Briefing Summary:"* ]]
    [[ "$output" == *"North Star:"* ]]
    [[ "$output" == *"Do Next (ordered 1-3):"* ]]
    [[ "$output" == *"Anti-tinker rule:"* ]]
    [[ "$output" == *"Health lens:"* ]]
    [[ "$output" == *"Signal confidence:"* ]]
    [[ "$output" == *"Evidence check:"* ]]
    [[ "$output" == *"non-fork GitHub activity as the primary evidence of the spear"* ]]
}

@test "coach_build_startday_prompt includes custom traps when traps.txt exists" {
    echo "Avoid yak-shaving dotfiles after 3pm" > "$DATA_DIR/traps.txt"

    run bash -c "$SOURCE_PREFIX; coach_build_startday_prompt \
        'focus' 'LOCKED' '' '' '' '' '' ''"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Personalized traps to avoid:"* ]]
    [[ "$output" == *"Avoid yak-shaving dotfiles after 3pm"* ]]
}

@test "coach_build_startday_prompt shows (none) defaults for empty inputs" {
    run bash -c "$SOURCE_PREFIX; coach_build_startday_prompt '' '' '' '' '' '' '' ''"

    [ "$status" -eq 0 ]
    [[ "$output" == *"(no focus set)"* ]]
    [[ "$output" == *"Yesterday's commits:"*"(none)"* ]]
    [[ "$output" == *"Top tasks:"*"(none)"* ]]
}

# ─── coach_build_goodevening_prompt ───────────────────────────────────────

@test "coach_build_goodevening_prompt includes all required schema sections" {
    run bash -c "$SOURCE_PREFIX; coach_build_goodevening_prompt \
        'OVERRIDE' 'Ship the logo' 'today commit' 'push data' \
        'done task' 'journal entry' 'digest blob'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Coach mode used today:"* ]]
    [[ "$output" == *"OVERRIDE"* ]]
    [[ "$output" == *"Today's focus:"* ]]
    [[ "$output" == *"Today's commits:"* ]]
    [[ "$output" == *"Completed tasks today:"* ]]
    [[ "$output" == *"Today's journal entries:"* ]]
    [[ "$output" == *"Behavior digest:"* ]]
    [[ "$output" == *"Reflection Summary:"* ]]
    [[ "$output" == *"What worked:"* ]]
    [[ "$output" == *"Where drift happened:"* ]]
    [[ "$output" == *"Likely trigger:"* ]]
    [[ "$output" == *"Pattern watch:"* ]]
    [[ "$output" == *"Tomorrow lock:"* ]]
    [[ "$output" == *"Health lens:"* ]]
    [[ "$output" == *"Signal confidence:"* ]]
    [[ "$output" == *"Evidence used:"* ]]
    [[ "$output" == *"declared focus and non-fork GitHub evidence"* ]]
}

@test "coach_build_goodevening_prompt includes custom traps when traps.txt exists" {
    echo "Stop refactoring at 9pm" > "$DATA_DIR/traps.txt"

    run bash -c "$SOURCE_PREFIX; coach_build_goodevening_prompt \
        'LOCKED' 'focus' '' '' '' '' ''"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Personalized traps to avoid:"* ]]
    [[ "$output" == *"Stop refactoring at 9pm"* ]]
}

# ─── coach_startday_fallback_output ───────────────────────────────────────

@test "startday fallback contains all required structural sections" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Ship the logo' 'LOCKED' \$'$DAY_MINUS1|Vectorize logo\n$DAY_MINUS1|Set schedule' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Briefing Summary:"* ]]
    [[ "$output" == *"North Star:"* ]]
    [[ "$output" == *"Do Next (ordered 1-3):"* ]]
    [[ "$output" == *"Operating insight (working + drift risk):"* ]]
    [[ "$output" == *"Anti-tinker rule:"* ]]
    [[ "$output" == *"Health lens:"* ]]
    [[ "$output" == *"Signal confidence:"* ]]
    [[ "$output" == *"Evidence check:"* ]]
}

@test "startday fallback extracts first task into Do Next step 1" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Ship the logo' 'LOCKED' \$'$DAY_MINUS1|Vectorize logo\n$DAY_MINUS1|Set schedule' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"starting: Vectorize logo"* ]]
}

@test "startday fallback LOCKED mode sets no-side-quest anti-tinker rule" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output 'focus' 'LOCKED' 'task' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"No side-quest work until Step 3 is complete"* ]]
}

@test "startday fallback OVERRIDE mode allows bounded exploration" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output 'focus' 'OVERRIDE' 'task' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"one 15-minute exploration slot"* ]]
}

@test "startday fallback RECOVERY mode enforces bare minimum tasks" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output 'focus' 'RECOVERY' 'task' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"1-2 bare minimum tasks"* ]]
}

@test "startday fallback health lens uses configurable thresholds" {
    run bash -c "COACH_LOW_ENERGY_THRESHOLD=3; COACH_HIGH_FOG_THRESHOLD=5; $SOURCE_PREFIX; coach_startday_fallback_output 'focus' 'LOCKED' 'task' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"under 3"* ]]
    [[ "$output" == *"above 5"* ]]
}

@test "startday fallback health lens uses default thresholds from config" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output 'focus' 'LOCKED' 'task' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"under 4"* ]]
    [[ "$output" == *"above 6"* ]]
}

@test "startday fallback includes reason in signal confidence" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output 'focus' 'LOCKED' 'task' 'error'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"LOW (AI error"* ]]
}

# ─── coach_goodevening_fallback_output ────────────────────────────────────

@test "goodevening fallback contains all required structural sections" {
    run bash -c "$SOURCE_PREFIX; coach_goodevening_fallback_output 'Ship the logo' 'LOCKED' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Reflection Summary:"* ]]
    [[ "$output" == *"What worked:"* ]]
    [[ "$output" == *"Where drift happened:"* ]]
    [[ "$output" == *"Likely trigger:"* ]]
    [[ "$output" == *"Tomorrow lock:"* ]]
    [[ "$output" == *"Health lens:"* ]]
    [[ "$output" == *"Pattern watch:"* ]]
    [[ "$output" == *"Signal confidence:"* ]]
    [[ "$output" == *"Evidence used:"* ]]
}

@test "goodevening fallback LOCKED mode sets no-side-quest boundary" {
    run bash -c "$SOURCE_PREFIX; coach_goodevening_fallback_output 'focus' 'LOCKED' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"No side quests before the first locked task block"* ]]
}

@test "goodevening fallback OVERRIDE mode allows bounded exploration" {
    run bash -c "$SOURCE_PREFIX; coach_goodevening_fallback_output 'focus' 'OVERRIDE' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"One bounded exploration block"* ]]
}

@test "goodevening fallback RECOVERY mode enforces aggressive simplicity" {
    run bash -c "$SOURCE_PREFIX; coach_goodevening_fallback_output 'focus' 'RECOVERY' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Aggressive simplicity"* ]]
}

@test "goodevening fallback includes reason in signal confidence" {
    run bash -c "$SOURCE_PREFIX; coach_goodevening_fallback_output 'focus' 'LOCKED' 'dispatcher-missing'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"LOW (AI dispatcher-missing"* ]]
}
