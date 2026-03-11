#!/usr/bin/env bats

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
    export TEST_ROOT
    TEST_ROOT="$(mktemp -d)"
    export DATA_DIR="$TEST_ROOT/data"
    export HEALTH_FILE="$DATA_DIR/health.txt"
    export DONE_FILE="$DATA_DIR/todo_done.txt"
    export BRIEFING_CACHE_FILE="$DATA_DIR/briefing_cache.txt"
    export COACH_ADHERENCE_FILE="$DATA_DIR/coach_adherence.txt"
    export PROJECTS_DIR="$TEST_ROOT/Projects"
    export COACH_LOW_ENERGY_THRESHOLD=4
    mkdir -p "$DATA_DIR"
    mkdir -p "$PROJECTS_DIR"

    # Source the metrics library
    source "$BATS_TEST_DIRNAME/../scripts/lib/date_utils.sh"
    source "$BATS_TEST_DIRNAME/../scripts/lib/coach_metrics.sh"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "coach_collect_tactical_metrics detects afternoon slump" {
    # Generate data indicating an afternoon slump (low energy after 14:00)
    local today
    today=$(date_today)
    cat <<EOF > "$HEALTH_FILE"
ENERGY|${today} 09:00:00|8
ENERGY|${today} 15:30:00|3
ENERGY|${today} 19:00:00|4
EOF

    run coach_collect_tactical_metrics "$today" 7
    assert_success
    assert_output_contains "afternoon_slump=true"

    # Generate data with NO afternoon slump (low energy morning only)
    cat <<EOF > "$HEALTH_FILE"
ENERGY|${today} 09:00:00|2
ENERGY|${today} 15:30:00|8
ENERGY|${today} 19:00:00|7
EOF

    run coach_collect_tactical_metrics "$today" 7
    assert_success
    assert_output_contains "afternoon_slump=false"
}

@test "coach_suggestion_adherence detects task completion overlap" {
    local anchor
    anchor="2024-01-02"
    local yesterday
    yesterday="2024-01-01"

    # Create fake 2024-01-01 briefing
    cat <<EOF > "$BRIEFING_CACHE_FILE"
$yesterday|Briefing Summary:\n- some stuff\nNorth Star:\n- do work\nDo Next (ordered 1-3):\n1. Fix critical bug in the core handler.\n2. Write documentation for the new API.\n3. Make coffee.\nOperating insight: ...
EOF

    # Case 1: adherence = low (no matching completions)
    cat <<EOF > "$DONE_FILE"
${yesterday} 10:00:00|review pull requests
${yesterday} 12:00:00|attend meeting
EOF

    run coach_suggestion_adherence "$anchor"
    assert_success
    assert_output_contains "suggestion_adherence=low"

    # Case 2: adherence = high (matching completions)
    cat <<EOF > "$DONE_FILE"
${yesterday} 10:00:00|review pull requests
${yesterday} 14:00:00|wrote API documentation
EOF

    run coach_suggestion_adherence "$anchor"
    assert_success
    assert_output_contains "suggestion_adherence=high"
}

@test "coach_record_suggestion_adherence upserts and rolling rate is computed" {
    local anchor="2024-01-05"
    coach_record_suggestion_adherence "2024-01-03" "low"
    coach_record_suggestion_adherence "2024-01-04" "high"
    coach_record_suggestion_adherence "2024-01-05" "low"
    coach_record_suggestion_adherence "2024-01-05" "high"

    local day_lines
    day_lines=$(grep -c "^2024-01-05|" "$COACH_ADHERENCE_FILE")
    [ "$day_lines" -eq 1 ]
    grep -q "^2024-01-05|high$" "$COACH_ADHERENCE_FILE"

    run coach_suggestion_adherence_rate "$anchor" 7
    assert_success
    assert_output_contains "suggestion_adherence_rate=66"
    assert_output_contains "suggestion_adherence_samples=3"
}

@test "coach_late_night_commits detects early morning pushes" {
    local anchor
    anchor="$(date_today)"

    # Needs a mock git repository with a commit matching the window
    local repo_dir="$PROJECTS_DIR/test-repo"
    mkdir -p "$repo_dir"
    git -C "$repo_dir" init >/dev/null 2>&1
    git -C "$repo_dir" config user.email "test@example.com"
    git -C "$repo_dir" config user.name "Test User"

    echo "test" > "$repo_dir/test.txt"
    git -C "$repo_dir" add test.txt

    # Set the commit time artificially to 02:30am today
    local late_date="${anchor} 02:30:00"
    GIT_AUTHOR_DATE="$late_date" GIT_COMMITTER_DATE="$late_date" git -C "$repo_dir" commit -m "Late night fix" >/dev/null 2>&1

    run coach_late_night_commits "$anchor"
    assert_success
    assert_output_contains "late_night_commits=true"
    assert_output_contains "02:30"
}

@test "coach_late_night_commits ignores daytime pushes" {
    local anchor
    anchor="$(date_today)"

    local repo_dir="$PROJECTS_DIR/test-repo-day"
    mkdir -p "$repo_dir"
    git -C "$repo_dir" init >/dev/null 2>&1
    git -C "$repo_dir" config user.email "test@example.com"
    git -C "$repo_dir" config user.name "Test User"

    echo "test" > "$repo_dir/test.txt"
    git -C "$repo_dir" add test.txt

    # Set the commit time artificially to 14:30pm today
    local day_date="${anchor} 14:30:00"
    GIT_AUTHOR_DATE="$day_date" GIT_COMMITTER_DATE="$day_date" git -C "$repo_dir" commit -m "Daytime fix" >/dev/null 2>&1

    run coach_late_night_commits "$anchor"
    assert_success
    assert_output_contains "late_night_commits=false"
}

@test "coach_focus_git_signal reports aligned focus with concentrated repo activity" {
    run coach_focus_git_signal \
        "Ship the dotfiles coach focus pass" \
        $'  • dotfiles (pushed today)\n  • dotfiles (pushed yesterday)' \
        $'  • dotfiles: ship coach focus pass (abc1234)\n  • dotfiles: tighten dotfiles coach signal (def5678)'

    assert_success
    assert_output_contains "focus_git_primary_repo=dotfiles"
    assert_output_contains "focus_git_commit_coherence=100"
    assert_output_contains "focus_git_status=aligned"
}

@test "coach_focus_git_signal reports repo-locked when pushes stay in one repo without commit evidence" {
    run coach_focus_git_signal \
        "Ship the dotfiles coach focus pass" \
        $'  • dotfiles (pushed today)\n  • dotfiles (pushed yesterday)' \
        ""

    assert_success
    assert_output_contains "focus_git_primary_repo=dotfiles"
    assert_output_contains "focus_git_status=repo-locked"
}

@test "coach_focus_git_signal reports mixed when coherence is between thresholds" {
    run coach_focus_git_signal \
        "Ship the dotfiles coach focus pass" \
        $'  • dotfiles (pushed today)' \
        $'  • dotfiles: ship coach focus pass (abc1234)\n  • dotfiles: update release notes (def5678)'

    assert_success
    assert_output_contains "focus_git_commit_coherence=50"
    assert_output_contains "focus_git_status=mixed"
}

@test "coach_focus_git_signal reports diffuse activity across unrelated repos" {
    run coach_focus_git_signal \
        "Ship the dotfiles coach focus pass" \
        $'  • dotfiles (pushed today)\n  • playground (pushed today)' \
        $'  • playground: explore random experiment (abc1234)\n  • notes-repo: tweak backlog copy (def5678)'

    assert_success
    assert_output_contains "focus_git_repo_count=3"
    assert_output_contains "focus_git_commit_coherence=0"
    assert_output_contains "focus_git_status=diffuse"
}

@test "coach_focus_git_signal reports no focus when focus text is empty" {
    run coach_focus_git_signal "" "" ""

    assert_success
    assert_output_contains "focus_git_status=no-focus"
}

@test "coach_focus_git_signal reports no Git evidence when activity is empty" {
    run coach_focus_git_signal "Ship the dotfiles coach focus pass" "" ""

    assert_success
    assert_output_contains "focus_git_status=no-git-evidence"
}

@test "coach_focus_git_signal reports Git signal unavailable separately from no activity" {
    run coach_focus_git_signal "Ship the dotfiles coach focus pass" "(GitHub signal unavailable)" ""

    assert_success
    assert_output_contains "focus_git_status=git-unavailable"
}
