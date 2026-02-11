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

setup() {
    export TEST_ROOT
    TEST_ROOT="$(mktemp -d)"
    export HOME="$TEST_ROOT/home"
    export DATA_DIR="$HOME/.config/dotfiles-data"
    export DOTFILES_DIR="$TEST_ROOT/dotfiles"
    mkdir -p "$DATA_DIR"
    mkdir -p "$DOTFILES_DIR"
    export COACH_LIB="$BATS_TEST_DIRNAME/../scripts/lib/coach_ops.sh"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "coach_collect_tactical_metrics extracts tactical window metrics" {
    cat > "$DATA_DIR/todo.txt" <<'EOF'
2026-02-01|old stale task
2026-02-08|active task
EOF
    cat > "$DATA_DIR/todo_done.txt" <<'EOF'
2026-02-09 10:00:00|done one
2026-02-10 11:00:00|done two
EOF
    cat > "$DATA_DIR/journal.txt" <<'EOF'
2026-02-09 08:00:00|journal one
2026-02-10 08:30:00|journal two
EOF
    cat > "$DATA_DIR/health.txt" <<'EOF'
ENERGY|2026-02-09 09:00|4
FOG|2026-02-09 09:00|6
EOF
    cat > "$DATA_DIR/spoons.txt" <<'EOF'
BUDGET|2026-02-09|7
SPEND|2026-02-09|12:00|3|work|4
EOF

    ts1=$(to_epoch "2026-02-09 09:30:00")
    ts2=$(to_epoch "2026-02-10 09:30:00")
    cat > "$DATA_DIR/dir_usage.log" <<EOF
$ts1|/tmp/proj-a
$ts2|/tmp/proj-b
EOF

    run bash -c "source '$COACH_LIB'; coach_collect_tactical_metrics '2026-02-10' '7' \$'  • dotfiles\n  • AI-Staff-HQ' \$'  • commit-a'"

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
    cat > "$DATA_DIR/todo_done.txt" <<'EOF'
2026-02-09 10:00:00|valid done line
not-a-valid-line
EOF
    cat > "$DATA_DIR/dir_usage.log" <<'EOF'
1770595200|/tmp/proj-a
malformed usage line
EOF

    run bash -c "source '$COACH_LIB'; coach_collect_data_quality_flags"

    [ "$status" -eq 0 ]
    [[ "$output" == *"todo_done_malformed=1"* ]]
    [[ "$output" == *"dir_usage_malformed=1"* ]]
}

@test "coach_build_behavior_digest classifies working signals and drift risks" {
    cat > "$DATA_DIR/todo.txt" <<'EOF'
2026-01-01|stale 1
2026-01-02|stale 2
2026-01-03|stale 3
2026-01-04|stale 4
2026-01-05|stale 5
EOF
    cat > "$DATA_DIR/todo_done.txt" <<'EOF'
2026-02-10 10:00:00|recent completion
EOF
    cat > "$DATA_DIR/journal.txt" <<'EOF'
2026-02-10 08:00:00|small note
EOF
    cat > "$DATA_DIR/health.txt" <<'EOF'
ENERGY|2026-02-10 09:00|3
FOG|2026-02-10 09:00|7
EOF
    cat > "$DATA_DIR/spoons.txt" <<'EOF'
BUDGET|2026-02-10|6
SPEND|2026-02-10|12:00|4|work|2
EOF
    cat > "$DATA_DIR/dir_usage.log" <<'EOF'
1770595200|/tmp/proj-a
EOF
    cat > "$DATA_DIR/focus_history.log" <<'EOF'
2026-02-10|focus update
EOF
    cat > "$DATA_DIR/dispatcher_usage.log" <<'EOF'
[2026-02-10 10:00:00] DISPATCHER: strategy, MODEL: x, PROMPT_TOKENS: 1, COMPLETION_TOKENS: 1, EST_COST: $0
EOF

    run bash -c "source '$COACH_LIB'; coach_build_behavior_digest '2026-02-10' '7' '30'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Working signals:"* ]]
    [[ "$output" == *"recent task completions are present"* ]]
    [[ "$output" == *"Drift risks:"* ]]
    [[ "$output" == *"stale task load is high (5)"* ]]
    [[ "$output" == *"average energy is low (3.0/10)"* ]]
    [[ "$output" == *"average brain fog is high (7.0/10)"* ]]
}

@test "coach_get_mode_for_date persists and reuses daily mode" {
    run bash -c "source '$COACH_LIB'; AI_COACH_MODE_DEFAULT=LOCKED; first=\$(coach_get_mode_for_date '2026-02-10' false); second=\$(coach_get_mode_for_date '2026-02-10' false); echo \"\$first|\$second\""

    [ "$status" -eq 0 ]
    [[ "$output" == *"LOCKED|LOCKED"* ]]
    line_count=$(wc -l < "$DATA_DIR/coach_mode.txt")
    [ "$line_count" -eq 1 ]
}

@test "coach_append_log escapes multiline and pipe content" {
    run bash -c "source '$COACH_LIB'; coach_append_log 'STARTDAY' '2026-02-10' 'LOCKED' 'focus|one' \$'m1\nm2|pipe' \$'line1\nline2|pipe'; tail -n 1 '$DATA_DIR/coach_log.txt'"

    [ "$status" -eq 0 ]
    line="$(printf '%s' "$output" | tail -n 1)"
    [[ "$line" == STARTDAY\|* ]]
    [[ "$line" == *"\\n"* ]]
    field_count=$(printf '%s\n' "$line" | awk -F'|' '{print NF}')
    [ "$field_count" -eq 7 ]
}

@test "_coach_extract_first_task skips headers and returns first real task" {
    run bash -c "source '$COACH_LIB'; _coach_extract_first_task \$'--- Top 3 Tasks ---\n1    2026-02-08   Vectorize the logo images for Aaron\n2    2026-02-08   Prepare posting times'"

    [ "$status" -eq 0 ]
    [ "$output" = "Vectorize the logo images for Aaron" ]
}

@test "_coach_extract_first_task handles pipe-delimited todo lines" {
    run bash -c "source '$COACH_LIB'; _coach_extract_first_task \$'2026-02-08|Vectorize logo\n2026-02-09|Set LinkedIn schedule'"

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

    run env COUNTER_FILE="$TEST_ROOT/counter.txt" PATH="$mock_bin:$PATH" bash -c "source '$COACH_LIB'; AI_COACH_RETRY_ON_TIMEOUT=true; coach_strategy_with_retry 'prompt' '0.25' '1' '4'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"retry success"* ]]
}

@test "coach_startday_response_is_grounded rejects ungrounded scope expansion" {
    run bash -c "source '$COACH_LIB'; coach_startday_response_is_grounded \$'North Star:\n- Test\nDo Next (ordered 1-3):\n1. Start Vectorize logo task.\n2. Create a folder named Coach and scaffold an endpoint.\n3. Verify endpoint output.\nOperating insight (working + drift risk):\n- note' 'Set up AI coach for the AI Briefings' \$'--- Top 3 Tasks ---\n1    2026-02-08   Vectorize the logo images for Aaron\n2    2026-02-08   Prepare and set posting times the Linkedin Article Series on content systems.'"

    [ "$status" -ne 0 ]
}
