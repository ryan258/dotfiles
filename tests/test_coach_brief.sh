#!/usr/bin/env bats

# test_coach_brief.sh - Bats coverage for deterministic coach briefs.

load helpers/test_helpers.sh
load helpers/assertions.sh

assert_success() {
    if [ "$status" -ne 0 ]; then
        echo "Expected success but got exit code: $status" >&2
        echo "Output: $output" >&2
        return 1
    fi
}

assert_output_contains() {
    local expected="$1"
    if [[ "$output" != *"$expected"* ]]; then
        echo "Expected output to contain: $expected" >&2
        echo "Actual output: $output" >&2
        return 1
    fi
}

setup() {
    setup_test_environment
    export DOTFILES_DIR="$TEST_DIR/dotfiles"
    export PROJECTS_DIR="$TEST_DIR/Projects"
    mkdir -p "$DOTFILES_DIR" "$PROJECTS_DIR"

    source "$BATS_TEST_DIRNAME/../scripts/lib/config.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/common.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/date_utils.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/focus_relevance.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/coach_metrics.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/coach_brief.sh"
}

teardown() {
    teardown_test_environment
}

@test "coach_brief_render_from_digest presents deterministic facts and signals" {
    local digest
    digest=$(cat <<'EOF'
Behavior digest (structured):
Tactical window: 7d ending 2026-03-26
  open_tasks=3, stale_tasks=1, completed_tasks=2, journal_entries=4, journal_focus_hits=2, drive_focus_hits_today=1, drive_focus_hits_week=3, drive_activity_hits_today=2, drive_activity_hits_week=5
  latest_energy=5 (2026-03-26 09:00), latest_fog=4 (2026-03-26 09:05), avg_energy=5.4, avg_fog=4.1, energy_3d=4->5->6 (improving), afternoon_slump=false, avg_spoon_budget=7.0, avg_spoon_spend=3.0
  unique_dirs=2, dir_switches=1, suggestion_adherence=high, suggestion_adherence_rate=75 (4 samples), late_night_commits=false, recent_pushes=2, commit_context=1
  strategy_evidence_sources=git,journal,drive
Pattern window: 30d ending 2026-03-26
  completion_trend=up (first=1, second=3)
  journal_trend=flat (first=2, second=2)
  focus_changes=2 (~0.5/week)
  top_directories=/tmp/dotfiles (3)
  top_dispatchers=tech (4)
  focus_git_status=aligned, primary_repo=dotfiles, primary_repo_share=100, commit_coherence=100, active_repos=1
  active_timer=none
  focus_git_reason=2 of 2 commits matched focus
  focus_coherence_secondary=80% (2 of 3 completed tasks matched focus)
Wearable context:
  - none
Working signals:
  - recent task completions are present
  - journal capture is active
Drift risks:
  - none detected
Data quality flags:
  - none
EOF
)

    run coach_brief_render_from_digest "startday" "2026-03-26" "Ship parser fix" "LOCKED" "$digest"

    assert_success
    assert_output_contains "Coach Brief"
    assert_output_contains "Flow: startday"
    assert_output_contains "Focus: Ship parser fix"
    assert_output_contains "Tasks: 3 open, 1 stale, 2 completed"
    assert_output_contains "Journal/Drive: 4 journal entries, 2 focus journal hits, 3 Drive focus hits, 5 Drive activity hits"
    assert_output_contains "Energy/Fog: latest energy 5 at 2026-03-26 09:00; average energy 5.4. Latest fog 4 at 2026-03-26 09:05; average fog 4.1."
    assert_output_contains "Completion trend: up (first=1, second=3)."
    assert_output_contains "Focus/Git: aligned; primary repo dotfiles; commit coherence 100; active repos 1."
    assert_output_contains "- recent task completions are present"
    assert_output_contains "- none"
}

@test "coach_brief_render builds a brief from existing coach metrics" {
    cat > "$TODO_FILE" <<'EOF'
1|2026-03-01|old stale task
2|2026-03-26|active task
EOF
    cat > "$DONE_FILE" <<'EOF'
2026-03-25 10:00:00|finish parser prep
2026-03-26 11:00:00|ship parser fix
EOF
    cat > "$JOURNAL_FILE" <<'EOF'
2026-03-25 08:00:00|Parser fix notes
2026-03-26 08:30:00|Parser ship plan
EOF
    cat > "$HEALTH_FILE" <<'EOF'
ENERGY|2026-03-26 09:00|5
FOG|2026-03-26 09:05|4
EOF
    cat > "$SPOON_LOG" <<'EOF'
BUDGET|2026-03-26|7
SPEND|2026-03-26|12:00|3|work|4
EOF
    cat > "$FOCUS_FILE" <<'EOF'
Ship parser fix
EOF

    run coach_brief_render \
        "startday" \
        "2026-03-26" \
        "Ship parser fix" \
        "LOCKED" \
        $'  - dotfiles (pushed today)' \
        $'  - dotfiles: ship parser fix (abc1234)'

    assert_success
    assert_output_contains "Coach Brief"
    assert_output_contains "Flow: startday"
    assert_output_contains "Tasks: 2 open"
    assert_output_contains "Journal/Drive:"
    assert_output_contains "Energy/Fog: latest energy 5"
    assert_output_contains "Patterns"
    assert_output_contains "Data Quality"
}
