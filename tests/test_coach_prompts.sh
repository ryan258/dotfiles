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
    [[ "$output" == *"GitHub blindspots/opportunities (1-5):"* ]]
    [[ "$output" == *"North Star:"* ]]
    [[ "$output" == *"Do Next (ordered 1-3):"* ]]
    [[ "$output" == *"Scope anchor:"* ]]
    [[ "$output" == *"Health lens:"* ]]
    [[ "$output" == *"non-fork GitHub activity as the primary signal for the spear"* ]]
    [[ "$output" == *"focus-related journal evidence and recent relevant Drive activity as valid strategy evidence"* ]]
    [[ "$output" == *"map of their interests"* ]]
    [[ "$output" == *"surface 3-5 blindspots, side-quests, or enhancement opportunities"* ]]
    [[ "$output" == *"Prefer 3-5 blindspots. Never exceed 5."* ]]
    [[ "$output" == *"one short A-E multiple-choice question"* ]]
    [[ "$output" == *"Additional local context bundle"* ]]
    [[ "$output" == *"secondary evidence for specificity and planning context"* ]]
    [[ "$output" == *"do not invent one. Step 1 should capture or choose the next concrete move"* ]]
    [[ "$output" == *"It is fine to validate strategy work when"* ]]
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
    [[ "$output" == *"Blindspots to sleep on (1-5):"* ]]
    [[ "$output" == *"What worked:"* ]]
    [[ "$output" == *"Off-script momentum:"* ]]
    [[ "$output" == *"What pulled you in:"* ]]
    [[ "$output" == *"Pattern watch:"* ]]
    [[ "$output" == *"Tomorrow lock:"* ]]
    [[ "$output" == *"Health lens:"* ]]
    [[ "$output" == *"declared focus and non-fork GitHub activity"* ]]
    [[ "$output" == *"focus-related journal evidence and recent relevant Drive activity as valid strategy evidence"* ]]
    [[ "$output" == *"Additional local context bundle"* ]]
    [[ "$output" == *"secondary evidence for specificity and recall"* ]]
    [[ "$output" == *"Prefer 3-5 blindspots. Never exceed 5."* ]]
    [[ "$output" == *"one short A-E multiple-choice question"* ]]
    [[ "$output" == *"Do not say journaling"* ]]
    [[ "$output" == *'`journal_entries`'* ]]
    [[ "$output" == *"Do not say task completion"* ]]
    [[ "$output" == *'`completed_tasks`'* ]]
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
    [[ "$output" == *"GitHub blindspots/opportunities (1-5):"* ]]
    [[ "$output" == *"Do Next (ordered 1-3):"* ]]
    [[ "$output" == *"Bias toward one immediate action"* ]]
    [[ "$output" == *"midpoint reset"* ]]
    [[ "$output" == *"one short A-E multiple-choice question"* ]]
    [[ "$output" == *"Additional local context bundle"* ]]
    [[ "$output" == *"secondary evidence for specificity and fast recentering"* ]]
    [[ "$output" == *"recent relevant Drive activity as valid strategy evidence"* ]]
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

# ─── coach_startday_fallback_output ───────────────────────────────────────

@test "startday fallback contains all required structural sections" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Ship the logo' 'LOCKED' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Briefing Summary:"* ]]
    [[ "$output" == *"GitHub blindspots/opportunities (1-5):"* ]]
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

@test "startday fallback uses focus Git and strategy evidence" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Making and polishing content for ryanleej.com' 'LOCKED' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"timeout"* ]]
    [[ "$output" == *"Fallback is based on today's focus, recent GitHub activity, and any focus-related strategy evidence"* ]]
    [[ "$output" == *"GitHub blindspots/opportunities (1-5):"* ]]
    [[ "$output" == *"Capture the first concrete move for today's focus (Making and polishing content for ryanleej.com)"* ]]
    [[ "$output" != *"top task"* ]]
}

@test "startday fallback counts strategy evidence when git output is thin" {
    run bash -c "$SOURCE_PREFIX; coach_startday_fallback_output \
        'Architecture review memo' 'LOCKED' 'timeout' \
        \$'Pattern window: 30d ending $DAY_MINUS1\n  focus_git_status=no-git-evidence\n  journal_focus_hits=2\n  drive_focus_hits_week=1\n  drive_recent_titles=Architecture review memo\n  strategy_evidence_sources=journal,drive'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"strategy evidence is present"* ]]
    [[ "$output" == *"Architecture review memo"* ]]
    [[ "$output" != *"spear movement is still unproven"* ]]
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
    [[ "$output" == *"1. Turn one shipped change from ai-ethics-comparator and youtube-face-blur into a write-up, changelog, or demo angle instead of starting from a blank page."* ]]
    [[ "$output" == *"5. Add one docs, demo, or test pass to the current lane so quality and legibility stop hiding behind feature momentum."* ]]
}

# ─── coach_goodevening_fallback_output ────────────────────────────────────

@test "goodevening fallback contains all required structural sections" {
    run bash -c "$SOURCE_PREFIX; coach_goodevening_fallback_output 'Ship the logo' 'LOCKED' 'timeout'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Reflection Summary:"* ]]
    [[ "$output" == *"Blindspots to sleep on (1-5):"* ]]
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
    [[ "$output" == *"Blindspots to sleep on (1-5):"* ]]
    [[ "$output" == *"1. Turn one shipped change from ai-ethics-comparator and youtube-face-blur into a write-up, changelog, or demo angle instead of starting from a blank page."* ]]
    [[ "$output" == *"3. In ai-ethics-comparator, do one small polish pass before opening a new lane."* ]]
}

@test "goodevening fallback counts strategy evidence on zero-commit days" {
    run bash -c "$SOURCE_PREFIX; coach_goodevening_fallback_output \
        'Architecture review memo' 'LOCKED' 'timeout' \
        \$'Pattern window: 30d ending $DAY_MINUS1\n  focus_git_status=no-git-evidence\n  journal_focus_hits=2\n  drive_focus_hits_today=1\n  drive_recent_titles=Architecture review memo\n  strategy_evidence_sources=journal,drive'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"strategy evidence is present"* ]]
    [[ "$output" == *"focus-related strategy work stayed visible"* ]]
    [[ "$output" != *"how to create one visible commit early tomorrow"* ]]
}

@test "coach_refine_response replaces unsupported journal claims in goodevening what worked" {
    local response
    local digest

    response=$'Reflection Summary:\n- You kept things moving.\nBlindspots to sleep on (1-5):\n1. Check dotfiles.\nWhat worked:\nJournaling and commit logging stayed active, giving you clear visibility into the day.\nOff-script momentum:\nYou explored.\nWhat pulled you in:\nIt was interesting.\nPattern watch:\nNot enough data for pattern detection.\nTomorrow lock:\nStart with one repo.\nHealth lens:\nKeep sessions bounded.\nTomorrow mode suggestion:\nTry LOCKED.'
    digest=$'Behavior digest (structured):\nTactical window: 7d ending 2026-03-30\n  open_tasks=1, stale_tasks=0, completed_tasks=2, journal_entries=0'

    printf '%s\n' "$response" > "$DATA_DIR/refine_response.txt"
    printf '%s\n' "$digest" > "$DATA_DIR/refine_digest.txt"

    run bash -c "$SOURCE_PREFIX; response=\$(cat '$DATA_DIR/refine_response.txt'); digest=\$(cat '$DATA_DIR/refine_digest.txt'); coach_refine_response \
        \"\$response\" 'goodevening' 'Ship the tracker' \$'  • dotfiles: feat: tighten tracker\n' \"\$digest\""

    [ "$status" -eq 0 ]
    [[ "$output" != *"Journaling and commit logging stayed active"* ]]
    [[ "$output" == *"What worked:"* ]]
    [[ "$output" == *"Ship the tracker"* ]]
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

@test "coach_build_startday_prompt renders cached drive snippets without exposing internal digest fields" {
    local snippet_b64
    snippet_b64="$(printf 'Architecture review memo excerpt' | base64 | tr -d '\n')"

    run bash -c "$SOURCE_PREFIX; coach_build_startday_prompt \
        'Architecture review memo' 'LOCKED' '' '' \$'Behavior digest (structured):\n  drive_recent_titles=Architecture review memo\n  drive_top_file_id=doc-1\n  drive_top_file_name=Architecture review memo\n  drive_top_file_snippet_b64=${snippet_b64}\n  strategy_evidence_sources=drive'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"### Recent Google Drive Document Excerpt: Architecture review memo"* ]]
    [[ "$output" == *"Architecture review memo excerpt"* ]]
    [[ "$output" != *"drive_top_file_id=doc-1"* ]]
    [[ "$output" != *"drive_top_file_snippet_b64="* ]]
}
