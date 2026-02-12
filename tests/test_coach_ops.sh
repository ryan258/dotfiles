#!/usr/bin/env bats

load helpers/test_helpers.sh
load helpers/assertions.sh

to_epoch() {
    python3 - "$1" <<'PY'
import sys
from datetime import datetime

print(int(datetime.strptime(sys.argv[1], "%Y-%m-%d %H:%M:%S").timestamp()))
PY
}

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
    mkdir -p "$DATA_DIR" "$DOTFILES_DIR"

    export ANCHOR_DAY
    ANCHOR_DAY="$(shift_date -1)"
    export DAY_MINUS1
    DAY_MINUS1="$(shift_date -2)"
    export DAY_MINUS2
    DAY_MINUS2="$(shift_date -3)"
    export OLD_DAY_1
    OLD_DAY_1="$(shift_date -40)"
    export OLD_DAY_2
    OLD_DAY_2="$(shift_date -41)"
    export OLD_DAY_3
    OLD_DAY_3="$(shift_date -42)"
    export OLD_DAY_4
    OLD_DAY_4="$(shift_date -43)"
    export OLD_DAY_5
    OLD_DAY_5="$(shift_date -44)"

    export COACH_LIB="$BATS_TEST_DIRNAME/../scripts/lib/coach_ops.sh"
    export COACH_CONFIG_LIB="$BATS_TEST_DIRNAME/../scripts/lib/config.sh"
    export COACH_COMMON_LIB="$BATS_TEST_DIRNAME/../scripts/lib/common.sh"
    export COACH_DATE_LIB="$BATS_TEST_DIRNAME/../scripts/lib/date_utils.sh"
    export COACH_SOURCE_PREFIX="source '$COACH_CONFIG_LIB'; source '$COACH_COMMON_LIB'; source '$COACH_DATE_LIB'; source '$COACH_LIB'"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "coach_collect_tactical_metrics extracts tactical window metrics" {
    cat > "$DATA_DIR/todo.txt" <<EOF
$OLD_DAY_1|old stale task
$DAY_MINUS1|active task
EOF
    cat > "$DATA_DIR/todo_done.txt" <<EOF
$DAY_MINUS1 10:00:00|done one
$ANCHOR_DAY 11:00:00|done two
EOF
    cat > "$DATA_DIR/journal.txt" <<EOF
$DAY_MINUS1 08:00:00|journal one
$ANCHOR_DAY 08:30:00|journal two
EOF
    cat > "$DATA_DIR/health.txt" <<EOF
ENERGY|$DAY_MINUS1 09:00|4
FOG|$DAY_MINUS1 09:00|6
EOF
    cat > "$DATA_DIR/spoons.txt" <<EOF
BUDGET|$DAY_MINUS1|7
SPEND|$DAY_MINUS1|12:00|3|work|4
EOF

    ts1=$(to_epoch "$DAY_MINUS1 09:30:00")
    ts2=$(to_epoch "$ANCHOR_DAY 09:30:00")
    cat > "$DATA_DIR/dir_usage.log" <<EOF
$ts1|/tmp/proj-a
$ts2|/tmp/proj-b
EOF

    run bash -c "$COACH_SOURCE_PREFIX; coach_collect_tactical_metrics '$ANCHOR_DAY' '7' \$'  • dotfiles\n  • AI-Staff-HQ' \$'  • commit-a'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"open_tasks=2"* ]]
    [[ "$output" == *"stale_tasks=1"* ]]
    [[ "$output" == *"completed_tasks=2"* ]]
    [[ "$output" == *"journal_entries=2"* ]]
    [[ "$output" == *"recent_pushes_count=2"* ]]
    [[ "$output" == *"commit_context_count=1"* ]]
    [[ "$output" == *"unique_dirs=2"* ]]
    [[ "$output" == *"dir_switches=1"* ]]
}

@test "coach_collect_data_quality_flags reports malformed lines" {
    cat > "$DATA_DIR/todo_done.txt" <<EOF
$DAY_MINUS1 10:00:00|valid done line
not-a-valid-line
EOF
    cat > "$DATA_DIR/dir_usage.log" <<'EOF'
1770595200|/tmp/proj-a
malformed usage line
EOF

    run bash -c "$COACH_SOURCE_PREFIX; coach_collect_data_quality_flags"

    [ "$status" -eq 0 ]
    [[ "$output" == *"todo_done_malformed=1"* ]]
    [[ "$output" == *"dir_usage_malformed=1"* ]]
}

@test "coach_build_behavior_digest classifies working signals and drift risks" {
    cat > "$DATA_DIR/todo.txt" <<EOF
$OLD_DAY_1|stale 1
$OLD_DAY_2|stale 2
$OLD_DAY_3|stale 3
$OLD_DAY_4|stale 4
$OLD_DAY_5|stale 5
EOF
    cat > "$DATA_DIR/todo_done.txt" <<EOF
$ANCHOR_DAY 10:00:00|recent completion
EOF
    cat > "$DATA_DIR/journal.txt" <<EOF
$ANCHOR_DAY 08:00:00|small note
EOF
    cat > "$DATA_DIR/health.txt" <<EOF
ENERGY|$ANCHOR_DAY 09:00|3
FOG|$ANCHOR_DAY 09:00|7
EOF
    cat > "$DATA_DIR/spoons.txt" <<EOF
BUDGET|$ANCHOR_DAY|6
SPEND|$ANCHOR_DAY|12:00|4|work|2
EOF
    cat > "$DATA_DIR/dir_usage.log" <<'EOF'
1770595200|/tmp/proj-a
EOF
    cat > "$DATA_DIR/focus_history.log" <<EOF
$ANCHOR_DAY|focus update
EOF
    cat > "$DATA_DIR/dispatcher_usage.log" <<EOF
[$ANCHOR_DAY 10:00:00] DISPATCHER: strategy, MODEL: x, PROMPT_TOKENS: 1, COMPLETION_TOKENS: 1, EST_COST: \$0
EOF

    run bash -c "$COACH_SOURCE_PREFIX; coach_build_behavior_digest '$ANCHOR_DAY' '7' '30'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Working signals:"* ]]
    [[ "$output" == *"recent task completions are present"* ]]
    [[ "$output" == *"Drift risks:"* ]]
    [[ "$output" == *"stale task load is high (5)"* ]]
    [[ "$output" == *"average energy is low (3.0/10)"* ]]
    [[ "$output" == *"average brain fog is high (7.0/10)"* ]]
}

@test "coach_get_mode_for_date persists and reuses daily mode" {
    run bash -c "$COACH_SOURCE_PREFIX; AI_COACH_MODE_DEFAULT=LOCKED; first=\$(coach_get_mode_for_date '$ANCHOR_DAY' false); second=\$(coach_get_mode_for_date '$ANCHOR_DAY' false); echo \"\$first|\$second\""

    [ "$status" -eq 0 ]
    [[ "$output" == *"LOCKED|LOCKED"* ]]
    line_count=$(wc -l < "$DATA_DIR/coach_mode.txt")
    [ "$line_count" -eq 1 ]
}

@test "coach_append_log escapes multiline and pipe content" {
    run bash -c "$COACH_SOURCE_PREFIX; coach_append_log 'STARTDAY' '$ANCHOR_DAY' 'LOCKED' 'focus|one' \$'m1\nm2|pipe' \$'line1\nline2|pipe'; tail -n 1 '$DATA_DIR/coach_log.txt'"

    [ "$status" -eq 0 ]
    line="$(printf '%s' "$output" | tail -n 1)"
    [[ "$line" == STARTDAY\|* ]]
    [[ "$line" == *"\\n"* ]]
    field_count=$(printf '%s\n' "$line" | awk -F'|' '{print NF}')
    [ "$field_count" -eq 7 ]
}

@test "_coach_extract_first_task skips headers and returns first real task" {
    run bash -c "$COACH_SOURCE_PREFIX; _coach_extract_first_task \$'--- Top 3 Tasks ---\n1    $DAY_MINUS2   Vectorize the logo images for Aaron\n2    $DAY_MINUS2   Prepare posting times'"

    [ "$status" -eq 0 ]
    [ "$output" = "Vectorize the logo images for Aaron" ]
}

@test "_coach_extract_first_task handles pipe-delimited todo lines" {
    run bash -c "$COACH_SOURCE_PREFIX; _coach_extract_first_task \$'$DAY_MINUS2|Vectorize logo\n$DAY_MINUS1|Set LinkedIn schedule'"

    [ "$status" -eq 0 ]
    [ "$output" = "Vectorize logo" ]
}

@test "coach_strategy_with_retry succeeds on second attempt after timeout" {
    mock_bin="$TEST_ROOT/bin"
    mkdir -p "$mock_bin"

    cat > "$mock_bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
COUNTER_FILE="${COUNTER_FILE:?missing}"
count="$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)"
count=$((count + 1))
echo "$count" > "$COUNTER_FILE"
if [ "$count" -eq 1 ]; then
  sleep 2
  echo "late first attempt"
else
  echo "retry success"
fi
EOF
    chmod +x "$mock_bin/dhp-strategy.sh"
    echo "0" > "$TEST_ROOT/counter.txt"

    run env COUNTER_FILE="$TEST_ROOT/counter.txt" PATH="$mock_bin:$PATH" bash -c "$COACH_SOURCE_PREFIX; AI_COACH_RETRY_ON_TIMEOUT=true; coach_strategy_with_retry 'prompt' '0.25' '1' '4'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"retry success"* ]]
}

@test "coach_startday_response_is_grounded rejects ungrounded scope expansion" {
    run bash -c "$COACH_SOURCE_PREFIX; coach_startday_response_is_grounded \$'North Star:\n- Test\nDo Next (ordered 1-3):\n1. Start Vectorize logo task.\n2. Create a folder named Coach and scaffold an endpoint.\n3. Verify endpoint output.\nOperating insight (working + drift risk):\n- note' 'Set up AI coach for the AI Briefings' \$'--- Top 3 Tasks ---\n1    $DAY_MINUS2   Vectorize the logo images for Aaron\n2    $DAY_MINUS2   Prepare and set posting times the Linkedin Article Series on content systems.'"

    [ "$status" -ne 0 ]
}
