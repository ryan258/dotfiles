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
    export HEALTH_LIB="$BATS_TEST_DIRNAME/../scripts/lib/health_ops.sh"
    export METRICS_LIB="$BATS_TEST_DIRNAME/../scripts/lib/coach_metrics.sh"
    export PROMPTS_LIB="$BATS_TEST_DIRNAME/../scripts/lib/coach_prompts.sh"
    export SOURCE_PREFIX="source '$CONFIG_LIB'; source '$COMMON_LIB'; source '$DATE_LIB'; source '$HEALTH_LIB'; source '$METRICS_LIB'; source '$PROMPTS_LIB'"

    export DAY_MINUS1
    DAY_MINUS1="$(shift_date -1)"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

# ─── coach_build_startday_prompt ──────────────────────────────────────────

@test "coach_build_startday_prompt includes all required schema sections" {
    run bash -c "$SOURCE_PREFIX; coach_build_startday_prompt \
        'Ship the logo' 'LOCKED' 'abc123 commit' 'dotfiles push' 'digest blob'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Today's focus:"* ]]
    [[ "$output" == *"Ship the logo"* ]]
    [[ "$output" == *"Coach mode for today:"* ]]
    [[ "$output" == *"LOCKED"* ]]
    [[ "$output" == *"Yesterday's commits:"* ]]
    [[ "$output" == *"Recent GitHub pushes"* ]]
    [[ "$output" == *"Behavior digest:"* ]]
    [[ "$output" == *"Wearable guidance:"* ]]
    [[ "$output" == *"Energy and fog guidance:"* ]]
    [[ "$output" == *"Briefing Summary:"* ]]
    [[ "$output" == *"GitHub blindspots/opportunities (1-10):"* ]]
    [[ "$output" == *"North Star:"* ]]
    [[ "$output" == *"Do Next (ordered 1-3):"* ]]
    [[ "$output" == *"Scope anchor:"* ]]
    [[ "$output" == *"Health lens:"* ]]
    [[ "$output" == *"non-fork GitHub activity as the primary signal for the spear"* ]]
    [[ "$output" == *"map of their interests"* ]]
    [[ "$output" == *"10 blindspots, side-quests, or enhancement opportunities"* ]]
    [[ "$output" == *"The GitHub blindspot/opportunity section must contain exactly 10 numbered lines."* ]]
    [[ "$output" == *"Keep journals and todos out of coaching"* ]]
    [[ "$output" == *"do not invent one. Step 1 should capture or choose the next concrete move"* ]]
    [[ "$output" == *"Do not mention journal evidence, journal momentum, todo completion"* ]]
}

@test "coach_build_startday_prompt includes custom traps when traps.txt exists" {
    echo "Avoid yak-shaving dotfiles after 3pm" > "$DATA_DIR/traps.txt"

    run bash -c "$SOURCE_PREFIX; coach_build_startday_prompt \
        'focus' 'LOCKED' '' '' ''"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Personalized traps to avoid:"* ]]
    [[ "$output" == *"Avoid yak-shaving dotfiles after 3pm"* ]]
}

@test "coach_build_startday_prompt shows (none) defaults for empty inputs" {
    run bash -c "$SOURCE_PREFIX; coach_build_startday_prompt '' '' '' '' ''"

    [ "$status" -eq 0 ]
    [[ "$output" == *"(no focus set)"* ]]
    [[ "$output" == *"Yesterday's commits:"*"(none)"* ]]
}

# ─── coach_build_goodevening_prompt ───────────────────────────────────────

@test "coach_build_goodevening_prompt includes all required schema sections" {
    run bash -c "$SOURCE_PREFIX; coach_build_goodevening_prompt \
        'OVERRIDE' 'Ship the logo' 'today commit' 'push data' 'digest blob'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Coach mode used today:"* ]]
    [[ "$output" == *"OVERRIDE"* ]]
    [[ "$output" == *"Today's focus:"* ]]
    [[ "$output" == *"Today's commits:"* ]]
    [[ "$output" == *"Behavior digest:"* ]]
    [[ "$output" == *"Wearable guidance:"* ]]
    [[ "$output" == *"Energy and fog guidance:"* ]]
    [[ "$output" == *"Reflection Summary:"* ]]
    [[ "$output" == *"Blindspots to sleep on (1-10):"* ]]
    [[ "$output" == *"What worked:"* ]]
    [[ "$output" == *"Off-script momentum:"* ]]
    [[ "$output" == *"What pulled you in:"* ]]
    [[ "$output" == *"Pattern watch:"* ]]
    [[ "$output" == *"Tomorrow lock:"* ]]
    [[ "$output" == *"Health lens:"* ]]
    [[ "$output" == *"declared focus and non-fork GitHub activity"* ]]
    [[ "$output" == *"Keep journals and todos out of the coaching verdict"* ]]
    [[ "$output" == *"The blindspot section must contain exactly 10 numbered lines."* ]]
}

@test "coach_build_goodevening_prompt includes custom traps when traps.txt exists" {
    echo "Stop refactoring at 9pm" > "$DATA_DIR/traps.txt"

    run bash -c "$SOURCE_PREFIX; coach_build_goodevening_prompt \
        'LOCKED' 'focus' '' '' ''"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Personalized traps to avoid:"* ]]
    [[ "$output" == *"Stop refactoring at 9pm"* ]]
}

@test "coach_build_status_prompt includes all required schema sections" {
    run bash -c "$SOURCE_PREFIX; coach_build_status_prompt \
        'LOCKED' 'Ship the logo' 'today commit' 'push data' 'digest blob' '/tmp/project' 'dotfiles'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Coach mode for today:"* ]]
    [[ "$output" == *"Today's focus:"* ]]
    [[ "$output" == *"Today's commits:"* ]]
    [[ "$output" == *"Recent GitHub pushes (last 7 days):"* ]]
    [[ "$output" == *"Behavior digest:"* ]]
    [[ "$output" == *"Energy and fog guidance:"* ]]
    [[ "$output" == *"Current directory:"* ]]
    [[ "$output" == *"/tmp/project"* ]]
    [[ "$output" == *"Current project context:"* ]]
    [[ "$output" == *"dotfiles"* ]]
    [[ "$output" == *"GitHub blindspots/opportunities (1-10):"* ]]
    [[ "$output" == *"Do Next (ordered 1-3):"* ]]
    [[ "$output" == *"Bias toward one immediate action"* ]]
}

# ─── coach_startday_fallback_output ───────────────────────────────────────

@test "startday fallback contains all required structural sections" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Ship the logo' 'LOCKED' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Briefing Summary:"* ]]
    [[ "$output" == *"GitHub blindspots/opportunities (1-10):"* ]]
    [[ "$output" == *"North Star:"* ]]
    [[ "$output" == *"Do Next (ordered 1-3):"* ]]
    [[ "$output" == *"Operating insight (momentum + exploration):"* ]]
    [[ "$output" == *"Scope anchor:"* ]]
    [[ "$output" == *"Health lens:"* ]]
}

@test "startday fallback stays focus-first even when todos exist elsewhere" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Ship the logo' 'LOCKED' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Capture the first concrete move for today's focus (Ship the logo)"* ]]
    [[ "$output" != *"Vectorize logo"* ]]
}

@test "startday fallback LOCKED mode sets no-side-quest scope anchor" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output 'focus' 'LOCKED' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"No side-quest work until Step 3 is complete"* ]]
}

@test "startday fallback OVERRIDE mode allows bounded exploration" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output 'focus' 'OVERRIDE' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"one 15-minute exploration slot"* ]]
}

@test "startday fallback RECOVERY mode enforces bare minimum tasks" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output 'focus' 'RECOVERY' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"1-2 bare minimum tasks"* ]]
}

@test "startday fallback health lens uses configurable thresholds" {
    run bash -c "COACH_LOW_ENERGY_THRESHOLD=3; COACH_HIGH_FOG_THRESHOLD=5; $SOURCE_PREFIX; coach_startday_fallback_output 'focus' 'LOCKED' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"under 3"* ]]
    [[ "$output" == *"above 5"* ]]
}

@test "startday fallback health lens uses default thresholds from config" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output 'focus' 'LOCKED' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"under 4"* ]]
    [[ "$output" == *"above 6"* ]]
}

@test "startday fallback includes the failure reason in the summary" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output 'focus' 'LOCKED' 'error'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"AI coaching was error; using deterministic fallback structure."* ]]
}

@test "startday fallback uses focus and Git only" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Making and polishing content for ryanleej.com' 'LOCKED' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"timeout"* ]]
    [[ "$output" == *"Fallback is based on today's focus and recent GitHub activity only."* ]]
    [[ "$output" == *"GitHub blindspots/opportunities (1-10):"* ]]
    [[ "$output" == *"Capture the first concrete move for today's focus (Making and polishing content for ryanleej.com)"* ]]
    [[ "$output" != *"top task"* ]]
}

@test "startday fallback cites focus Git drift when digest reports diffuse activity" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Making and polishing content for ryanleej.com' 'LOCKED' 'timeout' \
        \$'Pattern window: 30d ending $DAY_MINUS1\n  focus_git_status=diffuse, primary_repo=ai-ethics-comparator, primary_repo_share=57, commit_coherence=0, active_repos=5\n  focus_git_reason=0/6 commit cues match focus; activity spans 5 repos'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Recent non-fork GitHub activity is diffuse"* ]]
    [[ "$output" == *"activity spans 5 repos"* ]]
}

@test "startday fallback comments on recent commit repos when dispatcher times out" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Making and polishing content for ryanleej.com' 'LOCKED' 'timeout' \
        \$'Pattern window: 30d ending $DAY_MINUS1\n  focus_git_status=diffuse, primary_repo=ai-ethics-comparator, primary_repo_share=57, commit_coherence=16, active_repos=5\n  focus_git_reason=1/6 commit cues match focus; activity spans 5 repos' \
        \$'  • ai-ethics-comparator: Add experiments and counterfactuals\n  • youtube-face-blur: Rewrite thumbnail blurring flow'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Yesterday's actual GitHub work landed in ai-ethics-comparator and youtube-face-blur."* ]]
    [[ "$output" == *"Before reopening ai-ethics-comparator and youtube-face-blur, turn one real change from that work into one explicit Making and polishing content for ryanleej.com angle or task"* ]]
}

@test "startday fallback surfaces GitHub blindspot opportunity from feature-heavy commits" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Making and polishing content for ryanleej.com' 'LOCKED' 'timeout' \
        \$'Pattern window: 30d ending $DAY_MINUS1\n  focus_git_status=diffuse, primary_repo=ai-ethics-comparator, primary_repo_share=57, commit_coherence=16, active_repos=5\n  focus_git_reason=1/6 commit cues match focus; activity spans 5 repos' \
        \$'  • ai-ethics-comparator: feat: implement model fingerprinting\n  • youtube-face-blur: feat: rewrite thumbnail blurring flow'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"1. Recent work is feature-heavy across ai-ethics-comparator and youtube-face-blur; turn one shipped change into a write-up, changelog, or demo angle instead of starting from a blank page."* ]]
    [[ "$output" == *"10. Repo ai-ethics-comparator is a candidate for a README or changelog pass tied directly to the newest change."* ]]
}

# ─── coach_goodevening_fallback_output ────────────────────────────────────

@test "goodevening fallback contains all required structural sections" {
    run bash -c "$SOURCE_PREFIX; coach_goodevening_fallback_output 'Ship the logo' 'LOCKED' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Reflection Summary:"* ]]
    [[ "$output" == *"Blindspots to sleep on (1-10):"* ]]
    [[ "$output" == *"What worked:"* ]]
    [[ "$output" == *"Off-script momentum:"* ]]
    [[ "$output" == *"What pulled you in:"* ]]
    [[ "$output" == *"Tomorrow lock:"* ]]
    [[ "$output" == *"Health lens:"* ]]
    [[ "$output" == *"Pattern watch:"* ]]
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

@test "goodevening fallback includes the failure reason in the summary" {
    run bash -c "$SOURCE_PREFIX; coach_goodevening_fallback_output 'focus' 'LOCKED' 'dispatcher-missing'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"AI reflection was dispatcher missing; using deterministic fallback structure."* ]]
}

@test "goodevening fallback uses focus-first tomorrow lock instead of top-task placeholder" {
    run bash -c "$SOURCE_PREFIX; coach_goodevening_fallback_output \
        'Making and polishing content for ryanleej.com' 'LOCKED' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"First move: capture the first concrete move for Making and polishing content for ryanleej.com"* ]]
    [[ "$output" != *"top task aligned to focus"* ]]
}

@test "goodevening fallback cites focus Git drift when digest reports diffuse activity" {
    run bash -c "$SOURCE_PREFIX; coach_goodevening_fallback_output \
        'Making and polishing content for ryanleej.com' 'LOCKED' 'timeout' \
        \$'Pattern window: 30d ending $DAY_MINUS1\n  focus_git_status=diffuse, primary_repo=ai-ethics-comparator, primary_repo_share=57, commit_coherence=16, active_repos=5\n  focus_git_reason=1/6 commit cues match focus; activity spans 5 repos'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Recent non-fork GitHub activity was diffuse"* ]]
    [[ "$output" == *"activity spans 5 repos"* ]]
}

@test "goodevening fallback surfaces blindspots to sleep on from commit context" {
    run bash -c "$SOURCE_PREFIX; coach_goodevening_fallback_output \
        'Making and polishing content for ryanleej.com' 'LOCKED' 'timeout' \
        \$'Pattern window: 30d ending $DAY_MINUS1\n  focus_git_status=diffuse, primary_repo=ai-ethics-comparator, primary_repo_share=57, commit_coherence=16, active_repos=5\n  focus_git_reason=1/6 commit cues match focus; activity spans 5 repos' \
        \$'  • ai-ethics-comparator: feat: implement model fingerprinting\n  • youtube-face-blur: feat: rewrite thumbnail blurring flow'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Blindspots to sleep on (1-10):"* ]]
    [[ "$output" == *"1. Recent work is feature-heavy across ai-ethics-comparator and youtube-face-blur; turn one shipped change into a write-up, changelog, or demo angle instead of starting from a blank page."* ]]
    [[ "$output" == *"9. Repo youtube-face-blur likely wants a short demo, screenshot, or walkthrough so the newest capability is legible without code-reading."* ]]
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
    [[ "$output" == *"Fitbit sleep: 257m (2026-03-26)"* ]]
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
