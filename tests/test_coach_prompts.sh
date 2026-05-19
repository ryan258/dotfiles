#!/usr/bin/env bats

# test_coach_prompts.sh - Bats coverage for coach prompts.

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
    export COACH_MODE_FILE="$DATA_DIR/coach_mode.txt"
    export COACH_LOG_FILE="$DATA_DIR/coach_log.txt"
    export DOTFILES_DIR="$TEST_ROOT/dotfiles"
    mkdir -p "$DATA_DIR" "$DOTFILES_DIR"

    export CONFIG_LIB="$BATS_TEST_DIRNAME/../scripts/lib/config.sh"
    export COMMON_LIB="$BATS_TEST_DIRNAME/../scripts/lib/common.sh"
    export DATE_LIB="$BATS_TEST_DIRNAME/../scripts/lib/date_utils.sh"
    export HEALTH_LIB="$BATS_TEST_DIRNAME/../scripts/lib/health_ops.sh"
    export FOCUS_RELEVANCE_LIB="$BATS_TEST_DIRNAME/../scripts/lib/focus_relevance.sh"
    export METRICS_LIB="$BATS_TEST_DIRNAME/../scripts/lib/coach_metrics.sh"
    export PROMPTS_LIB="$BATS_TEST_DIRNAME/../scripts/lib/coach_prompts.sh"
    export SOURCE_PREFIX="source '$CONFIG_LIB'; source '$COMMON_LIB'; source '$DATE_LIB'; source '$HEALTH_LIB'; source '$FOCUS_RELEVANCE_LIB'; source '$METRICS_LIB'; source '$PROMPTS_LIB'"

    export DAY_MINUS1
    DAY_MINUS1="$(shift_date -1)"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "coach_prompts requires coach_metrics to be sourced first" {
    run bash -c "source '$CONFIG_LIB'; source '$COMMON_LIB'; source '$DATE_LIB'; source '$HEALTH_LIB'; source '$FOCUS_RELEVANCE_LIB'; source '$PROMPTS_LIB'"

    [ "$status" -ne 0 ]
    [[ "$output" == *"coach_metrics.sh must be sourced before coach_prompts.sh"* ]]
}

@test "coach_build_prebrief_questions caps prompts at three questions" {
    run bash -c "AI_COACH_PREBRIEF_ALWAYS_ASK=true; AI_COACH_PREBRIEF_MAX_QUESTIONS=3; $SOURCE_PREFIX; coach_build_prebrief_questions \
        'status' '' 'LOCKED' 'git data' \$'Pattern window: 30d ending $DAY_MINUS1\n  focus_git_status=diffuse, primary_repo=dotfiles, primary_repo_share=57, commit_coherence=0, active_repos=4\nHealth window:\n  latest_energy=7 ($DAY_MINUS1 13:02), latest_fog=3 ($DAY_MINUS1 13:02)' \
        '/tmp/project' 'dotfiles' 'repo-local'"

    [ "$status" -eq 0 ]
    question_count="$(printf '%s\n' "$output" | grep -c '^Q|')"
    [ "$question_count" -eq 3 ]
    [[ "$output" == *"Q|1|Lane|"* ]]
    [[ "$output" == *"Q|2|Priority|"* ]]
    [[ "$output" == *"Q|3|Pacing|"* ]]
    [[ "$output" == *"O|1|A|Declared focus|"* ]]
    [[ "$output" == *"O|2|B|Narrow scope|"* ]]
    [[ "$output" == *"O|3|E|Custom|"* ]]
}

@test "coach_prebrief_answers_to_context parses one-line numbered answers" {
    run bash -c "AI_COACH_PREBRIEF_ALWAYS_ASK=true; $SOURCE_PREFIX; \
        questions=\$(coach_build_prebrief_questions 'status' '' 'LOCKED' 'git data' '' '/tmp/project' 'dotfiles' 'repo-local'); \
        coach_prebrief_answers_to_context \"\$questions\" '1B 2A 3E (keep it quiet)'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"- Lane: Current repo lane. Let recent repo or GitHub momentum lead the advice."* ]]
    [[ "$output" == *"- Priority: Concrete next move. Bias the briefing toward one clear first step."* ]]
    [[ "$output" == *"- Pacing: custom - keep it quiet"* ]]
}

@test "coach_collect_local_context_bundle includes raw local slices" {
    local now_epoch
    now_epoch="$(to_epoch "$DAY_MINUS1 12:00:00")"
    cat > "$DATA_DIR/journal.txt" <<EOF
$DAY_MINUS1 08:00:00|Journal line
EOF
    cat > "$DATA_DIR/todo.txt" <<EOF
1|$DAY_MINUS1|Ship the logo
EOF
    cat > "$DATA_DIR/health.txt" <<EOF
ENERGY|$DAY_MINUS1 09:00|6
EOF
    cat > "$DATA_DIR/spoons.txt" <<EOF
BUDGET|$DAY_MINUS1|10
EOF
    cat > "$DATA_DIR/dir_usage.log" <<EOF
$now_epoch|/Users/ryanjohnson/dotfiles
EOF
    cat > "$DATA_DIR/tomorrow_launchpad" <<'EOF'
Tomorrow lock:
- First move: Ship the logo.
EOF
    mkdir -p "$HOME/Documents/Reviews/Weekly"
    cat > "$HOME/Documents/Reviews/Weekly/2026-W13.md" <<'EOF'
# Weekly Review
One good thing.
EOF

    run bash -c "$SOURCE_PREFIX; coach_collect_local_context_bundle 'startday' '$DAY_MINUS1' '/tmp/project' 'global'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Raw journal entries (last 7 days):"* ]]
    [[ "$output" == *"Journal line"* ]]
    [[ "$output" == *"Raw open todo lines (last 7 days):"* ]]
    [[ "$output" == *"Ship the logo"* ]]
    [[ "$output" == *"Raw health log lines (last 7 days):"* ]]
    [[ "$output" == *"ENERGY|$DAY_MINUS1 09:00|6"* ]]
    [[ "$output" == *"Raw spoon log lines (last 7 days):"* ]]
    [[ "$output" == *"BUDGET|$DAY_MINUS1|10"* ]]
    [[ "$output" == *"Raw directory log lines (last 7 days):"* ]]
    [[ "$output" == *"/Users/ryanjohnson/dotfiles"* ]]
    [[ "$output" == *"Yesterday's prep or launchpad text:"* ]]
    [[ "$output" == *"Tomorrow lock:"* ]]
    [[ "$output" == *"Weekly review text:"* ]]
    [[ "$output" == *"# Weekly Review"* ]]
}

@test "coach_build_behavior_digest includes wearable context when Fitbit data exists" {
    mkdir -p "$DATA_DIR/fitbit"
    cat > "$DATA_DIR/fitbit/sleep_minutes.txt" <<'EOF'
2026-03-26|257
EOF
    cat > "$DATA_DIR/fitbit/resting_heart_rate.txt" <<'EOF'
2026-03-26|73
EOF
    cat > "$DATA_DIR/fitbit/hrv.txt" <<'EOF'
2026-03-26|67
EOF
    cat > "$DATA_DIR/fitbit/steps.txt" <<'EOF'
2026-03-26|822
EOF

    run bash -c "$SOURCE_PREFIX; coach_build_behavior_digest '2026-03-26' 7 30 '' ''"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Wearable context:"* ]]
    [[ "$output" == *"Fitbit sleep: 4h 17m (2026-03-26)"* ]]
    [[ "$output" == *"Fitbit resting HR: 73 (2026-03-26)"* ]]
    [[ "$output" == *"Fitbit HRV: 67 (2026-03-26)"* ]]
    [[ "$output" == *"Fitbit steps: 822 (2026-03-26)"* ]]
}

@test "coach_build_behavior_digest includes both latest and average energy fog context" {
    cat > "$DATA_DIR/health.txt" <<'EOF'
ENERGY|2026-03-23 01:14|2
FOG|2026-03-23 01:14|8
ENERGY|2026-03-23 10:54|10
FOG|2026-03-23 10:54|2
ENERGY|2026-03-23 23:24|3
FOG|2026-03-23 23:24|7
ENERGY|2026-03-26 13:02|7
FOG|2026-03-26 13:02|3
EOF

    run bash -c "$SOURCE_PREFIX; coach_build_behavior_digest '2026-03-26' 7 30 '' ''"

    [ "$status" -eq 0 ]
    [[ "$output" == *"latest_energy=7 (2026-03-26 13:02), latest_fog=3 (2026-03-26 13:02), avg_energy=5.5, avg_fog=5.0"* ]]
}

@test "coach_build_behavior_digest includes focus-related strategy evidence fields" {
    cat > "$DATA_DIR/daily_focus.txt" <<'EOF'
Architecture review memo
EOF
    cat > "$DATA_DIR/journal.txt" <<'EOF'
2026-03-26 08:00:00|Architecture review memo outline
EOF
    mkdir -p "$DOTFILES_DIR/scripts"
    cat > "$DOTFILES_DIR/scripts/drive.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "recent" && "${2:-}" == "1" ]]; then
  cat <<'JSON'
[{"id":"doc-1","name":"Architecture review memo"}]
JSON
elif [[ "${1:-}" == "read" && "${2:-}" == "doc-1" ]]; then
  printf 'Architecture review memo excerpt'
else
  cat <<'JSON'
[{"id":"doc-1","name":"Architecture review memo"},{"id":"doc-2","name":"System design notes"}]
JSON
fi
EOF
    chmod +x "$DOTFILES_DIR/scripts/drive.sh"

    run bash -c "$SOURCE_PREFIX; coach_build_behavior_digest '2026-03-26' 7 30 '' ''"

    [ "$status" -eq 0 ]
    [[ "$output" == *"journal_focus_hits=1"* ]]
    [[ "$output" == *"drive_focus_hits_today=1"* ]]
    [[ "$output" == *"drive_focus_hits_week=2"* ]]
    [[ "$output" == *"drive_top_file_id=doc-1"* ]]
    [[ "$output" == *"drive_top_file_name=Architecture review memo"* ]]
    [[ "$output" == *"drive_top_file_snippet_b64="* ]]
    [[ "$output" == *"strategy_evidence_sources=journal,drive"* ]]
}
