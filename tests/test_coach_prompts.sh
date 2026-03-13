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
        'Ship the logo' 'LOCKED' 'abc123 commit' 'dotfiles push' 'digest blob'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Today's focus:"* ]]
    [[ "$output" == *"Ship the logo"* ]]
    [[ "$output" == *"Coach mode for today:"* ]]
    [[ "$output" == *"LOCKED"* ]]
    [[ "$output" == *"Yesterday's commits:"* ]]
    [[ "$output" == *"Recent GitHub pushes"* ]]
    [[ "$output" == *"Behavior digest:"* ]]
    [[ "$output" == *"Briefing Summary:"* ]]
    [[ "$output" == *"GitHub blindspots/opportunities (1-10):"* ]]
    [[ "$output" == *"North Star:"* ]]
    [[ "$output" == *"Do Next (ordered 1-3):"* ]]
    [[ "$output" == *"Anti-tinker rule:"* ]]
    [[ "$output" == *"Health lens:"* ]]
    [[ "$output" == *"Signal confidence:"* ]]
    [[ "$output" == *"Evidence check:"* ]]
    [[ "$output" == *"non-fork GitHub activity as the primary evidence of the spear"* ]]
    [[ "$output" == *"single source of truth for project insight"* ]]
    [[ "$output" == *"10 blindspots or enhancement opportunities"* ]]
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
    [[ "$output" == *"Reflection Summary:"* ]]
    [[ "$output" == *"Blindspots to sleep on (1-10):"* ]]
    [[ "$output" == *"What worked:"* ]]
    [[ "$output" == *"Where drift happened:"* ]]
    [[ "$output" == *"Likely trigger:"* ]]
    [[ "$output" == *"Pattern watch:"* ]]
    [[ "$output" == *"Tomorrow lock:"* ]]
    [[ "$output" == *"Health lens:"* ]]
    [[ "$output" == *"Signal confidence:"* ]]
    [[ "$output" == *"Evidence used:"* ]]
    [[ "$output" == *"declared focus and non-fork GitHub evidence"* ]]
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

# ─── coach_startday_fallback_output ───────────────────────────────────────

@test "startday fallback contains all required structural sections" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Ship the logo' 'LOCKED' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Briefing Summary:"* ]]
    [[ "$output" == *"GitHub blindspots/opportunities (1-10):"* ]]
    [[ "$output" == *"North Star:"* ]]
    [[ "$output" == *"Do Next (ordered 1-3):"* ]]
    [[ "$output" == *"Operating insight (working + drift risk):"* ]]
    [[ "$output" == *"Anti-tinker rule:"* ]]
    [[ "$output" == *"Health lens:"* ]]
    [[ "$output" == *"Signal confidence:"* ]]
    [[ "$output" == *"Evidence check:"* ]]
}

@test "startday fallback stays focus-first even when todos exist elsewhere" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Ship the logo' 'LOCKED' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Capture the first concrete move for today's focus (Ship the logo)"* ]]
    [[ "$output" != *"Vectorize logo"* ]]
}

@test "startday fallback LOCKED mode sets no-side-quest anti-tinker rule" {
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

@test "startday fallback includes reason in signal confidence" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output 'focus' 'LOCKED' 'error'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"LOW (AI error"* ]]
}

@test "startday fallback uses focus and Git only" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Making and polishing content for ryanleej.com' 'LOCKED' 'ungrounded-actions'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"AI briefing failed evidence check"* ]]
    [[ "$output" == *"Fallback is grounded in today's focus and recent GitHub activity only."* ]]
    [[ "$output" == *"GitHub blindspots/opportunities (1-10):"* ]]
    [[ "$output" == *"Capture the first concrete move for today's focus (Making and polishing content for ryanleej.com)"* ]]
    [[ "$output" != *"top task"* ]]
}

@test "startday fallback surfaces evidence-check detail when provided" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Making and polishing content for ryanleej.com' 'LOCKED' 'ungrounded-actions' '' '' 'invented repo/page/publish detail; line=\"publish the polished homepage copy.\"'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Evidence-check detail: invented repo/page/publish detail; line=\"publish the polished homepage copy.\"."* ]]
}

@test "startday fallback cites focus Git drift when digest reports diffuse activity" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Making and polishing content for ryanleej.com' 'LOCKED' 'ungrounded-actions' \
        \$'Pattern window: 30d ending $DAY_MINUS1\n  focus_git_status=diffuse, primary_repo=ai-ethics-comparator, primary_repo_share=57, commit_coherence=0, active_repos=5\n  focus_git_reason=0/6 commit cues match focus; activity spans 5 repos'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deterministic fallback (AI briefing failed evidence check)"* ]]
    [[ "$output" == *"Recent non-fork GitHub activity is diffuse"* ]]
    [[ "$output" == *"activity spans 5 repos"* ]]
    [[ "$output" == *"focus_git_status=diffuse"* ]]
    [[ "$output" == *"primary_repo=ai-ethics-comparator"* ]]
}

@test "startday fallback comments on recent commit repos when AI evidence check fails" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Making and polishing content for ryanleej.com' 'LOCKED' 'ungrounded-actions' \
        \$'Pattern window: 30d ending $DAY_MINUS1\n  focus_git_status=diffuse, primary_repo=ai-ethics-comparator, primary_repo_share=57, commit_coherence=16, active_repos=5\n  focus_git_reason=1/6 commit cues match focus; activity spans 5 repos' \
        \$'  • ai-ethics-comparator: Add experiments and counterfactuals\n  • youtube-face-blur: Rewrite thumbnail blurring flow'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Yesterday's actual GitHub work landed in ai-ethics-comparator and youtube-face-blur."* ]]
    [[ "$output" == *"Before reopening ai-ethics-comparator and youtube-face-blur, turn one real change from that work into one explicit Making and polishing content for ryanleej.com angle or task"* ]]
}

@test "startday fallback surfaces GitHub blindspot opportunity from feature-heavy commits" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Making and polishing content for ryanleej.com' 'LOCKED' 'ungrounded-actions' \
        \$'Pattern window: 30d ending $DAY_MINUS1\n  focus_git_status=diffuse, primary_repo=ai-ethics-comparator, primary_repo_share=57, commit_coherence=16, active_repos=5\n  focus_git_reason=1/6 commit cues match focus; activity spans 5 repos' \
        \$'  • ai-ethics-comparator: feat: implement model fingerprinting\n  • youtube-face-blur: feat: rewrite thumbnail blurring flow'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"1. Recent work is feature-heavy across ai-ethics-comparator and youtube-face-blur; turn one shipped change into a write-up, changelog, or demo angle instead of starting from a blank page."* ]]
    [[ "$output" == *"10. Repo ai-ethics-comparator is a candidate for a README or changelog pass tied directly to the newest change."* ]]
    [[ "$output" == *"github_opportunity_scan"* ]]
}

# ─── coach_goodevening_fallback_output ────────────────────────────────────

@test "goodevening fallback contains all required structural sections" {
    run bash -c "$SOURCE_PREFIX; coach_goodevening_fallback_output 'Ship the logo' 'LOCKED' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Reflection Summary:"* ]]
    [[ "$output" == *"Blindspots to sleep on (1-10):"* ]]
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
    [[ "$output" == *"LOW (AI dispatcher missing"* ]]
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
    [[ "$output" == *"focus_git_status=diffuse"* ]]
}

@test "goodevening fallback surfaces blindspots to sleep on from commit context" {
    run bash -c "$SOURCE_PREFIX; coach_goodevening_fallback_output \
        'Making and polishing content for ryanleej.com' 'LOCKED' 'ungrounded-reflection' \
        \$'Pattern window: 30d ending $DAY_MINUS1\n  focus_git_status=diffuse, primary_repo=ai-ethics-comparator, primary_repo_share=57, commit_coherence=16, active_repos=5\n  focus_git_reason=1/6 commit cues match focus; activity spans 5 repos' \
        \$'  • ai-ethics-comparator: feat: implement model fingerprinting\n  • youtube-face-blur: feat: rewrite thumbnail blurring flow'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Blindspots to sleep on (1-10):"* ]]
    [[ "$output" == *"1. Recent work is feature-heavy across ai-ethics-comparator and youtube-face-blur; turn one shipped change into a write-up, changelog, or demo angle instead of starting from a blank page."* ]]
    [[ "$output" == *"9. Repo youtube-face-blur likely wants a short demo, screenshot, or walkthrough so the newest capability is legible without code-reading."* ]]
    [[ "$output" == *"github_opportunity_scan"* ]]
}

@test "coach_sanitize_startday_blindspots removes noisy blindspot lines and backfills grounded GitHub ideas" {
    run bash -c "$SOURCE_PREFIX; coach_sanitize_startday_blindspots \
        \$'Briefing Summary:\n- note\nGitHub blindspots/opportunities (1-10):\n1. dir_usage_malformed=162 means your system is broken.\n2. focus_git_status=diffuse proves the spear is broken.\n3. commit_context is missing so there is nothing to learn.\n4. High brain fog score suggests a mismatch between cognitive load and capacity.\n5. Low suggestion adherence rate implies planned interventions are being ignored.\n6. Keep the repo lane visible to future you.\nNorth Star:\n- Ship one visible move.' \
        'Making and polishing content for ryanleej.com' \
        \$'Pattern window: 30d ending $DAY_MINUS1\n  focus_git_status=diffuse, primary_repo=ai-ethics-comparator, primary_repo_share=57, commit_coherence=16, active_repos=5\n  focus_git_reason=1/6 commit cues match focus; activity spans 5 repos' \
        \$'  • ai-ethics-comparator: feat: implement model fingerprinting\n  • youtube-face-blur: feat: rewrite thumbnail blurring flow'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"GitHub blindspots/opportunities (1-10):"* ]]
    [[ "$output" == *"1. Keep the repo lane visible to future you."* ]]
    [[ "$output" == *"Recent work is feature-heavy across ai-ethics-comparator and youtube-face-blur"* ]]
    [[ "$output" != *"dir_usage_malformed"* ]]
    [[ "$output" != *"focus_git_status=diffuse proves"* ]]
    [[ "$output" != *"commit_context is missing"* ]]
    [[ "$output" != *"High brain fog score"* ]]
    [[ "$output" != *"Low suggestion adherence rate"* ]]
}

@test "coach_sanitize_goodevening_blindspots inserts a cleaned blindspot section before What worked" {
    run bash -c "$SOURCE_PREFIX; coach_sanitize_goodevening_blindspots \
        \$'Reflection Summary:\n- note\nWhat worked:\n- Focus stayed mostly inside one lane.\nTomorrow lock:\n- First move: resume the repo lane.\n- Done condition: ship one visible next step.\n- Anti-tinker boundary: no side quests before the first block lands.' \
        'Making and polishing content for ryanleej.com' \
        \$'Pattern window: 30d ending $DAY_MINUS1\n  focus_git_status=diffuse, primary_repo=ai-ethics-comparator, primary_repo_share=57, commit_coherence=16, active_repos=5\n  focus_git_reason=1/6 commit cues match focus; activity spans 5 repos' \
        \$'  • ai-ethics-comparator: feat: implement model fingerprinting\n  • youtube-face-blur: feat: rewrite thumbnail blurring flow'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Blindspots to sleep on (1-10):"* ]]
    [[ "$output" == *"Recent work is feature-heavy across ai-ethics-comparator and youtube-face-blur"* ]]
    [[ "$output" == *$'Blindspots to sleep on (1-10):\n1. Recent work is feature-heavy'* ]]
    [[ "$output" == *$'10. Repo ai-ethics-comparator is a candidate for a README or changelog pass tied directly to the newest change.\nWhat worked:'* ]]
}
