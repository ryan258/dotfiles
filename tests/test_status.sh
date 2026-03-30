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
    export DOTFILES_DIR="$TEST_ROOT/dotfiles"
    export PROJECTS_DIR="$TEST_ROOT/projects"
    mkdir -p "$DATA_DIR" "$DOTFILES_DIR/scripts/lib" "$DOTFILES_DIR/bin" "$PROJECTS_DIR"

    # Copy core libraries
    for lib in common.sh config.sh date_utils.sh file_ops.sh spoon_budget.sh health_ops.sh github_ops.sh coach_ops.sh coach_metrics.sh coach_prompts.sh coach_scoring.sh coaching.sh loader.sh; do
        if [ -f "$BATS_TEST_DIRNAME/../scripts/lib/$lib" ]; then
            cp "$BATS_TEST_DIRNAME/../scripts/lib/$lib" "$DOTFILES_DIR/scripts/lib/$lib"
        fi
    done
    cp "$BATS_TEST_DIRNAME/../scripts/status.sh" "$DOTFILES_DIR/scripts/status.sh"
    chmod +x "$DOTFILES_DIR/scripts/status.sh"

    # Minimal todo.sh stub
    cat > "$DOTFILES_DIR/scripts/todo.sh" <<'STUB'
#!/usr/bin/env bash
echo "  1. Sample task"
STUB
    chmod +x "$DOTFILES_DIR/scripts/todo.sh"

    cat > "$DOTFILES_DIR/scripts/github_helper.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    list_commits_for_date)
        if [ -n "${GITHUB_COMMITS_FIXTURE:-}" ] && [ -f "$GITHUB_COMMITS_FIXTURE" ]; then
            cat "$GITHUB_COMMITS_FIXTURE"
        fi
        ;;
    list_repos|list_user_events)
        if [ -n "${GITHUB_REPOS_FIXTURE:-}" ] && [ -f "$GITHUB_REPOS_FIXTURE" ]; then
            cat "$GITHUB_REPOS_FIXTURE"
        else
            echo "[]"
        fi
        ;;
esac
STUB
    chmod +x "$DOTFILES_DIR/scripts/github_helper.sh"

    cat > "$DOTFILES_DIR/bin/dhp-coach.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$DATA_DIR/status_coach_args.txt"
cat > "$DATA_DIR/status_coach_prompt.txt"
cat <<'OUT'
Briefing Summary:
- Mid-day repo signal is clear.
GitHub blindspots/opportunities (1-5):
1. Repo dotfiles likely wants one visible polish pass before new feature work.
2. Repo dotfiles could use one short demo or README example tied to the latest change.
3. Repo dotfiles may have one setup friction point worth removing before adding more features.
4. Repo dotfiles is a candidate for a changelog note tied to the current lane.
5. Repo dotfiles likely has one reusable helper worth extracting.
North Star:
- Keep the next block inside the logo work in dotfiles.
Do Next (ordered 1-3):
1. Capture the next concrete logo move in dotfiles and start it now.
2. Keep the same repo open for one more short block.
3. Done when one focused block lands.
Operating insight (momentum + exploration):
- Working: focus is explicit. Drift risk: repo switching.
Scope anchor:
- No repo switch until the block lands.
Health lens:
- Use one short block and then reassess.
OUT
STUB
    chmod +x "$DOTFILES_DIR/bin/dhp-coach.sh"

    export TODAY
    TODAY="$(date +%Y-%m-%d)"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

_run_status() {
    env \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        AI_STATUS_ENABLED="" \
        "$@" \
        bash "$DOTFILES_DIR/scripts/status.sh" < /dev/null
}

make_test_repo() {
    local repo_dir="$1"

    mkdir -p "$repo_dir"
    git init "$repo_dir" >/dev/null 2>&1
    (
        cd "$repo_dir" || exit 1
        git config user.name "Test User"
        git config user.email "test@example.com"
        echo "seed" > README.md
        git add README.md
        git commit -m "seed" >/dev/null 2>&1
    )
}

# ─── Core sections ────────────────────────────────────────────────────────

@test "status.sh exits 0 and shows expected section headers" {
    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"TODAY'S FOCUS:"* ]]
    [[ "$output" == *"DAILY CONTEXT:"* ]]
    [[ "$output" == *"WHERE YOU ARE:"* ]]
    [[ "$output" == *"TODAY'S JOURNAL"* ]]
    [[ "$output" == *"TASKS:"* ]]
}

@test "status.sh does not show AI status coach by default" {
    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" != *"STATUS COACH:"* ]]
}

@test "status.sh shows focus when focus file exists" {
    echo "Ship the logo" > "$DATA_DIR/daily_focus.txt"

    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"Ship the logo"* ]]
}

@test "status.sh shows no-focus placeholder when focus file is missing" {
    rm -f "$DATA_DIR/daily_focus.txt"

    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"(No focus set)"* ]]
}

# ─── DAILY CONTEXT section ────────────────────────────────────────────────

@test "status.sh DAILY CONTEXT shows mode from coach_mode file" {
    echo "${TODAY}|OVERRIDE" > "$COACH_MODE_FILE"

    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode: OVERRIDE"* ]]
}

@test "status.sh DAILY CONTEXT defaults mode to LOCKED when no mode file exists" {
    rm -f "$COACH_MODE_FILE"

    run _run_status AI_COACH_MODE_DEFAULT=LOCKED

    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode: LOCKED"* ]]
}

@test "status.sh DAILY CONTEXT defaults mode when mode file has no entry for today" {
    local yesterday
    yesterday="$(shift_date -1)"
    echo "${yesterday}|RECOVERY" > "$COACH_MODE_FILE"

    run _run_status AI_COACH_MODE_DEFAULT=LOCKED

    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode: LOCKED"* ]]
}

@test "status.sh DAILY CONTEXT shows spoon budget and remaining" {
    cat > "$DATA_DIR/spoons.txt" <<EOF
BUDGET|${TODAY}|8
SPEND|${TODAY}|10:00|3|deep-work|5
EOF

    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"Spoons: 5/8 remaining"* ]]
}

@test "status.sh DAILY CONTEXT shows full budget when no spoons spent" {
    cat > "$DATA_DIR/spoons.txt" <<EOF
BUDGET|${TODAY}|12
EOF

    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"Spoons: 12/12 remaining"* ]]
}

@test "status.sh DAILY CONTEXT shows ? remaining when no spoon log exists" {
    rm -f "$DATA_DIR/spoons.txt"

    run _run_status DEFAULT_DAILY_SPOONS=10

    [ "$status" -eq 0 ]
    [[ "$output" == *"Spoons: ?/10 remaining"* ]]
}

@test "status.sh shows inactive repos and repo-local tracking when the current repo is parked" {
    make_test_repo "$PROJECTS_DIR/dotfiles"
    printf '%s\n' "dotfiles|${TODAY}|good place" > "$DATA_DIR/github_inactive_repos.txt"

    run env \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        AI_STATUS_ENABLED="" \
        bash -lc "cd '$PROJECTS_DIR/dotfiles' && bash '$DOTFILES_DIR/scripts/status.sh' < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Repo tracking: inactive until reactivated"* ]]
    [[ "$output" == *"⏸️ INACTIVE REPOS (reactivate to track again):"* ]]
    [[ "$output" == *"dotfiles (inactive ${TODAY} - good place)"* ]]
}

@test "status.sh DAILY CONTEXT shows focus and spear alignment from Git evidence" {
    echo "logo" > "$DATA_DIR/daily_focus.txt"
    cat > "$DATA_DIR/github_commits.txt" <<'EOF'
dotfiles|abc1234|ship logo
EOF

    run _run_status GITHUB_COMMITS_FIXTURE="$DATA_DIR/github_commits.txt"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Focus: logo"* ]]
    [[ "$output" == *"Spear alignment: aligned via dotfiles (100% commit coherence; 1 repo active)"* ]]
}

@test "status.sh --coach renders AI status coach section and builds a status-specific prompt" {
    echo "logo" > "$DATA_DIR/daily_focus.txt"
    cat > "$DATA_DIR/github_commits.txt" <<'EOF'
dotfiles|abc1234|ship logo
EOF

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        GITHUB_COMMITS_FIXTURE="$DATA_DIR/github_commits.txt" \
        bash "$DOTFILES_DIR/scripts/status.sh" --coach < /dev/null

    [ "$status" -eq 0 ]
    [[ "$output" == *"🤖 STATUS COACH:"* ]]
    [[ "$output" == *"Keep the next block inside the logo work in dotfiles."* ]]
    [ -f "$DATA_DIR/status_coach_prompt.txt" ]
    prompt="$(cat "$DATA_DIR/status_coach_prompt.txt")"
    [[ "$prompt" == *"Current directory:"* ]]
    [[ "$prompt" == *"Current project context:"* ]]
    [[ "$prompt" == *"Today's commits:"* ]]
    [[ "$prompt" == *"Recent GitHub pushes (last 7 days):"* ]]
    [[ "$prompt" == *"Additional local context bundle:"* ]]
    [[ "$prompt" == *"Raw health log lines (last 7 days):"* ]]
    [[ "$prompt" == *"Wearable guidance:"* ]]
}

@test "status.sh --coach captures same-run energy and fog before building the coach prompt" {
    local runner="$TEST_ROOT/run_status_with_tty.sh"

    cat > "$DOTFILES_DIR/scripts/health.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

timestamp="${TEST_HEALTH_TIMESTAMP:-$(date '+%Y-%m-%d %H:%M')}"

case "${1:-}" in
    energy)
        printf 'ENERGY|%s|%s\n' "$timestamp" "${2:-}" >> "$DATA_DIR/health.txt"
        printf 'Logged energy level: %s/10\n' "${2:-}"
        ;;
    fog)
        printf 'FOG|%s|%s\n' "$timestamp" "${2:-}" >> "$DATA_DIR/health.txt"
        printf 'Logged brain fog level: %s/10\n' "${2:-}"
        ;;
esac
STUB
    chmod +x "$DOTFILES_DIR/scripts/health.sh"

    cat > "$runner" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export HOME="$HOME"
export DATA_DIR="$DATA_DIR"
export DOTFILES_DIR="$DOTFILES_DIR"
export PROJECTS_DIR="$PROJECTS_DIR"
export PATH="$DOTFILES_DIR/bin:\$PATH"
export AI_COACH_CHAT_ENABLED=false
export AI_COACH_PREBRIEF_ENABLED=false
export TEST_HEALTH_TIMESTAMP="${TODAY} 13:02"
/usr/bin/expect <<'EXPECT'
set timeout 20
spawn bash \$env(DOTFILES_DIR)/scripts/status.sh --coach
expect -re {Log Energy/Fog levels\\? \\[y/N\\]: $}
send -- "y\r"
expect -re {Energy Level \\(1-10\\): $}
send -- "7\r"
expect -re {Brain Fog Level \\(1-10\\): $}
send -- "3\r"
expect eof
EXPECT
EOF
    chmod +x "$runner"

    run bash "$runner"

    [ "$status" -eq 0 ]
    [ -f "$DATA_DIR/status_coach_prompt.txt" ]
    prompt="$(cat "$DATA_DIR/status_coach_prompt.txt")"
    [[ "$prompt" == *"latest_energy=7 (${TODAY} 13:02), latest_fog=3 (${TODAY} 13:02)"* ]]
}

@test "status.sh --coach collects one-line pre-brief answers before building the prompt" {
    local runner="$TEST_ROOT/run_status_prebrief_with_tty.sh"

    echo "logo" > "$DATA_DIR/daily_focus.txt"
    cat > "$DATA_DIR/github_commits.txt" <<'EOF'
dotfiles|abc1234|ship logo
EOF

    cat > "$runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export HOME="$HOME"
export DATA_DIR="$DATA_DIR"
export DOTFILES_DIR="$DOTFILES_DIR"
export PROJECTS_DIR="$PROJECTS_DIR"
export PATH="$DOTFILES_DIR/bin:$PATH"
export GITHUB_COMMITS_FIXTURE="$DATA_DIR/github_commits.txt"
export AI_COACH_CHAT_ENABLED=false
export AI_COACH_PREBRIEF_ALWAYS_ASK=true
export AI_COACH_PREBRIEF_MAX_QUESTIONS=3
/usr/bin/expect <<'EXPECT'
set timeout 20
spawn bash $env(DOTFILES_DIR)/scripts/status.sh --coach
expect -re {PRE-BRIEF CHECK:}
expect -re {Pre-brief answers \[Enter to skip\]: $}
send -- "1B 2A 3E (keep it quiet)\r"
expect eof
EXPECT
EOF
    chmod +x "$runner"

    run bash "$runner"

    [ "$status" -eq 0 ]
    [ -f "$DATA_DIR/status_coach_prompt.txt" ]
    prompt="$(cat "$DATA_DIR/status_coach_prompt.txt")"
    [[ "$prompt" == *"Pre-brief clarifications:"* ]]
    [[ "$prompt" == *"- Lane: Current repo lane. Let recent repo or GitHub momentum lead the advice."* ]]
    [[ "$prompt" == *"- Priority: Concrete next move. Bias the briefing toward one clear first step."* ]]
    [[ "$prompt" == *"- Pacing: custom - keep it quiet"* ]]
    [[ "$prompt" != *"PRE-BRIEF CHECK:"* ]]
}

@test "status.sh auto-syncs Fitbit data before rendering when auth exists" {
    cat > "$DOTFILES_DIR/scripts/fitbit_sync.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$DATA_DIR/fitbit_sync_args_status.txt"
STUB
    chmod +x "$DOTFILES_DIR/scripts/fitbit_sync.sh"
    printf '%s\n' '{"refresh_token":"test"}' > "$DATA_DIR/google_health_oauth.json"

    run _run_status GOOGLE_HEALTH_DEFAULT_DAYS=14

    [ "$status" -eq 0 ]
    [ -f "$DATA_DIR/fitbit_sync_args_status.txt" ]
    [[ "$(cat "$DATA_DIR/fitbit_sync_args_status.txt")" == "sync 14" ]]
}

@test "status.sh --coach passes no-focus placeholder into the status coach prompt" {
    rm -f "$DATA_DIR/daily_focus.txt"
    cat > "$DATA_DIR/github_commits.txt" <<'EOF'
dotfiles|abc1234|ship logo
EOF

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        GITHUB_COMMITS_FIXTURE="$DATA_DIR/github_commits.txt" \
        bash "$DOTFILES_DIR/scripts/status.sh" --coach < /dev/null

    [ "$status" -eq 0 ]
    prompt="$(cat "$DATA_DIR/status_coach_prompt.txt")"
    [[ "$prompt" == *"Today's focus:"*$'\n'"(no focus set)"* ]]
}

@test "status.sh --coach scopes the prompt to the current git repo when run inside one" {
    local repo_dir="$PROJECTS_DIR/dotfiles"

    echo "logo" > "$DATA_DIR/daily_focus.txt"
    make_test_repo "$repo_dir"
    cat > "$DATA_DIR/github_commits.txt" <<'EOF'
dotfiles|abc1234|ship logo
other-repo|def5678|ship unrelated feature
EOF

    cd "$repo_dir"
    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        GITHUB_COMMITS_FIXTURE="$DATA_DIR/github_commits.txt" \
        bash "$DOTFILES_DIR/scripts/status.sh" --coach < /dev/null

    [ "$status" -eq 0 ]
    prompt="$(cat "$DATA_DIR/status_coach_prompt.txt")"
    [[ "$prompt" == *"Context scope:"*$'\n'"repo-local"* ]]
    [[ "$prompt" == *"• dotfiles: ship logo (abc1234)"* ]]
    [[ "$prompt" != *"• other-repo: ship unrelated feature (def5678)"* ]]
}

@test "status.sh --coach keeps global repo context when run outside a git repo" {
    local non_repo_dir="$TEST_ROOT/non-repo"

    echo "logo" > "$DATA_DIR/daily_focus.txt"
    mkdir -p "$non_repo_dir"
    cat > "$DATA_DIR/github_commits.txt" <<'EOF'
dotfiles|abc1234|ship logo
other-repo|def5678|ship unrelated feature
EOF

    cd "$non_repo_dir"
    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        GITHUB_COMMITS_FIXTURE="$DATA_DIR/github_commits.txt" \
        bash "$DOTFILES_DIR/scripts/status.sh" --coach < /dev/null

    [ "$status" -eq 0 ]
    prompt="$(cat "$DATA_DIR/status_coach_prompt.txt")"
    [[ "$prompt" == *"Context scope:"*$'\n'"global"* ]]
    [[ "$prompt" == *"• dotfiles: ship logo (abc1234)"* ]]
    [[ "$prompt" == *"• other-repo: ship unrelated feature (def5678)"* ]]
}

@test "status.sh --coach preserves raw AI output in repo-local mode" {
    local repo_dir="$PROJECTS_DIR/dotfiles"

    echo "logo" > "$DATA_DIR/daily_focus.txt"
    make_test_repo "$repo_dir"
    cat > "$DOTFILES_DIR/bin/dhp-coach.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
cat > /dev/null
cat <<'OUT'
Briefing Summary:
- Current GitHub lane is dotfiles, but declared focus is elsewhere.
GitHub blindspots/opportunities (1-10):
1. Repo dotfiles likely wants one polish pass.
2. Repo dotfiles could use one demo.
3. Repo dotfiles may have one setup friction point.
4. Repo dotfiles is a candidate for a changelog note.
5. Repo dotfiles likely has one reusable helper worth extracting.
6. Repo dotfiles may need one stability pass.
7. Repo dotfiles can likely yield one write-up angle.
8. Repo dotfiles probably wants a clearer finish line.
9. Repo dotfiles may hide one tiny cleanup.
10. Repo dotfiles likely benefits from one walkthrough.
North Star:
- Bridge the focus gap.
Do Next:
1. Commit one tiny change in dotfiles.
2. Switch to ai-ethics-comparator and inspect the PDF module.
3. Done when both repos are open.
Operating insight (momentum + exploration):
- Working: dotfiles is active. Drift risk: switching.
Scope anchor:
- Stay in dotfiles until the tiny change lands, then switch to ai-ethics-comparator.
Health lens:
- Keep the block short.
OUT
STUB
    chmod +x "$DOTFILES_DIR/bin/dhp-coach.sh"

    cd "$repo_dir"
    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        bash "$DOTFILES_DIR/scripts/status.sh" --coach < /dev/null

    [ "$status" -eq 0 ]
    [[ "$output" == *"Do Next:"* ]]
    [[ "$output" == *"Commit one tiny change in dotfiles."* ]]
    [[ "$output" == *"Switch to ai-ethics-comparator and inspect the PDF module."* ]]
}

@test "status.sh --coach filters noisy blindspots when the dispatcher returns output" {
    echo "logo" > "$DATA_DIR/daily_focus.txt"
    cat > "$DOTFILES_DIR/bin/dhp-coach.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
cat > /dev/null
cat <<'OUT'
Briefing Summary:
- Mid-day repo signal is clear.
GitHub blindspots/opportunities (1-10):
1. dir_usage_malformed=162 means the system is unstable.
2. focus_git_status=diffuse proves the spear is broken.
3. commit context (0) means we cannot verify local work.
4. Repo dotfiles likely wants one visible polish pass before new feature work.
North Star:
- Keep the next block inside dotfiles.
Do Next (ordered 1-3):
1. Capture the next concrete dotfiles move and start it now.
2. Keep the same repo open for one more short block.
3. Done when one focused block lands.
Operating insight (momentum + exploration):
- Working: focus is explicit. Drift risk: repo switching.
Scope anchor:
- No repo switch until the block lands.
Health lens:
- Use one short block and then reassess.
OUT
STUB
    chmod +x "$DOTFILES_DIR/bin/dhp-coach.sh"
    cat > "$DATA_DIR/github_commits.txt" <<'EOF'
dotfiles|abc1234|ship logo
EOF

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        GITHUB_COMMITS_FIXTURE="$DATA_DIR/github_commits.txt" \
        bash "$DOTFILES_DIR/scripts/status.sh" --coach < /dev/null

    [ "$status" -eq 0 ]
    [[ "$output" == *"GitHub blindspots/opportunities (1-5):"* ]]
    [[ "$output" != *"dir_usage_malformed=162 means the system is unstable."* ]]
    [[ "$output" != *"focus_git_status=diffuse proves the spear is broken."* ]]
    [[ "$output" != *"commit context (0) means we cannot verify local work."* ]]
    [[ "$output" == *"1. Repo dotfiles likely wants one visible polish pass before new feature work."* ]]
}

@test "status.sh --coach uses deterministic fallback when no dispatcher is available" {
    echo "logo" > "$DATA_DIR/daily_focus.txt"
    rm -f "$DOTFILES_DIR/bin/dhp-coach.sh"
    cat > "$DATA_DIR/github_commits.txt" <<'EOF'
dotfiles|abc1234|ship logo
EOF

    run env \
        PATH="$DOTFILES_DIR/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        GITHUB_COMMITS_FIXTURE="$DATA_DIR/github_commits.txt" \
        bash "$DOTFILES_DIR/scripts/status.sh" --coach < /dev/null

    [ "$status" -eq 0 ]
    [[ "$output" == *"AI status coach was dispatcher missing; using deterministic fallback structure."* ]]
}

# ─── Journal section ─────────────────────────────────────────────────────

@test "status.sh shows today's journal entries" {
    cat > "$DATA_DIR/journal.txt" <<EOF
${TODAY} 09:00:00|Morning reflection on goals
${TODAY} 14:00:00|Afternoon progress note
EOF

    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"Morning reflection on goals"* ]]
    [[ "$output" == *"Afternoon progress note"* ]]
}

@test "status.sh shows placeholder when no journal entries for today" {
    local yesterday
    yesterday="$(shift_date -1)"
    cat > "$DATA_DIR/journal.txt" <<EOF
${yesterday} 09:00:00|Yesterday entry
EOF

    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"(No entries for today yet)"* ]]
}

# ─── Last journal entry ──────────────────────────────────────────────────

@test "status.sh shows last journal entry in WHERE YOU ARE section" {
    cat > "$DATA_DIR/journal.txt" <<EOF
${TODAY} 08:00:00|First entry
${TODAY} 16:00:00|Last entry of the day
EOF

    run _run_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"Last journal entry:"*"Last entry of the day"* ]]
}

# ─── Section ordering ────────────────────────────────────────────────────

@test "status.sh DAILY CONTEXT appears between FOCUS and WHERE YOU ARE" {
    echo "My focus" > "$DATA_DIR/daily_focus.txt"

    run _run_status

    [ "$status" -eq 0 ]

    # Extract line numbers for section headers
    focus_line=$(echo "$output" | grep -n "TODAY'S FOCUS:" | head -1 | cut -d: -f1)
    context_line=$(echo "$output" | grep -n "DAILY CONTEXT:" | head -1 | cut -d: -f1)
    where_line=$(echo "$output" | grep -n "WHERE YOU ARE:" | head -1 | cut -d: -f1)

    [ -n "$focus_line" ]
    [ -n "$context_line" ]
    [ -n "$where_line" ]
    [ "$focus_line" -lt "$context_line" ]
    [ "$context_line" -lt "$where_line" ]
}
