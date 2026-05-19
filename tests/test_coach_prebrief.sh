#!/usr/bin/env bats

# test_coach_prebrief.sh - Bats coverage for interactive coach pre-brief helpers.

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
    setup_test_environment
    export PREBRIEF_LIB="$BATS_TEST_DIRNAME/../scripts/lib/coach_prebrief.sh"
    export SOURCE_PREFIX="source '$PREBRIEF_LIB'"

    export DAY_MINUS1
    DAY_MINUS1="$(shift_date -1)"
}

teardown() {
    teardown_test_environment
}

@test "coach_prebrief can be sourced without coach prompts" {
    run bash -c "$SOURCE_PREFIX; type coach_build_prebrief_questions >/dev/null"

    [ "$status" -eq 0 ]
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
