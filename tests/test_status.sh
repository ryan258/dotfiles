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
    for lib in common.sh config.sh date_utils.sh file_ops.sh spoon_budget.sh health_ops.sh github_ops.sh coach_metrics.sh coach_prompts.sh coach_scoring.sh coaching.sh; do
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
        echo "[]"
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
GitHub blindspots/opportunities (1-10):
1. Repo dotfiles likely wants one visible polish pass before new feature work.
2. Repo dotfiles could use one short demo or README example tied to the latest change.
3. Repo dotfiles may have one setup friction point worth removing before adding more features.
4. Repo dotfiles is a candidate for a changelog note tied to the current lane.
5. Repo dotfiles likely has one reusable helper worth extracting.
6. Repo dotfiles may need one stability pass before the next feature wave.
7. Repo dotfiles can likely yield one write-up or artifact angle from today's work.
8. Repo dotfiles probably wants a clearer finish line for the next block.
9. Repo dotfiles may hide one tiny cleanup that would make the latest change more legible.
10. Repo dotfiles likely benefits from one screenshot, example, or walkthrough.
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
Evidence check:
- focus text + commit repos + recent pushes.
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
        AI_COACH_EVIDENCE_CHECK_ENABLED=true \
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
        AI_COACH_EVIDENCE_CHECK_ENABLED=true \
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
        AI_COACH_EVIDENCE_CHECK_ENABLED=true \
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
        AI_COACH_EVIDENCE_CHECK_ENABLED=true \
        bash "$DOTFILES_DIR/scripts/status.sh" --coach < /dev/null

    [ "$status" -eq 0 ]
    prompt="$(cat "$DATA_DIR/status_coach_prompt.txt")"
    [[ "$prompt" == *"Context scope:"*$'\n'"global"* ]]
    [[ "$prompt" == *"• dotfiles: ship logo (abc1234)"* ]]
    [[ "$prompt" == *"• other-repo: ship unrelated feature (def5678)"* ]]
}

@test "status.sh --coach keeps Do Next inside the current repo in repo-local mode" {
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
Evidence check:
- focus + repo context.
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
        AI_COACH_EVIDENCE_CHECK_ENABLED=false \
        bash "$DOTFILES_DIR/scripts/status.sh" --coach < /dev/null

    [ "$status" -eq 0 ]
    [[ "$output" == *"Do Next (ordered 1-3):"* ]]
    [[ "$output" == *"Pick one concrete next move inside dotfiles"* ]]
    [[ "$output" == *"Keep the same dotfiles repo open for one more short block before switching lanes."* ]]
    [[ "$output" == *"Do not leave dotfiles until Step 3 is complete"* ]]
    [[ "$output" != *"Switch to ai-ethics-comparator"* ]]
}

@test "status.sh --coach rewrites bold markdown sections cleanly in repo-local mode" {
    local repo_dir="$PROJECTS_DIR/dotfiles"

    echo "logo" > "$DATA_DIR/daily_focus.txt"
    make_test_repo "$repo_dir"
    cat > "$DOTFILES_DIR/bin/dhp-coach.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
cat > /dev/null
cat <<'OUT'
**Briefing Summary:**
- Current GitHub lane is dotfiles, but declared focus is elsewhere.

**GitHub blindspots/opportunities (1-10):**
1. dotfiles could use one polish pass.
2. dotfiles could use one demo.
3. dotfiles could use one README pass.
4. dotfiles could use one cleanup.
5. dotfiles could use one setup fix.
6. dotfiles could use one automation pass.
7. dotfiles could use one changelog note.
8. dotfiles could use one helper extraction.
9. dotfiles could use one walkthrough.
10. dotfiles could use one test pass.

**North Star:**
- Bridge the focus gap.

**Do Next (ordered 1-3):**
1. Open ai-ethics-comparator and start the PDF work.
2. Switch back to dotfiles later if needed.
3. Done when both repos are open.

**Operating insight (momentum + exploration):**
- Working: dotfiles is active. Drift risk: switching.

**Scope anchor:**
- Stay in ai-ethics-comparator until the sequence is complete.

**Health lens:**
- Keep the block short.

**Evidence check:**
- focus + repo context.
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
        AI_COACH_EVIDENCE_CHECK_ENABLED=false \
        bash "$DOTFILES_DIR/scripts/status.sh" --coach < /dev/null

    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c "Do Next (ordered 1-3):")" -eq 1 ]
    [ "$(printf '%s\n' "$output" | grep -c "GitHub blindspots/opportunities (1-10):")" -eq 1 ]
    [[ "$output" == *"Pick one concrete next move inside dotfiles"* ]]
    [[ "$output" != *"Open ai-ethics-comparator and start the PDF work."* ]]
}

@test "status.sh --coach cleans noisy blindspots when evidence check is disabled" {
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
Evidence check:
- focus text + commit repos + recent pushes.
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
        AI_COACH_EVIDENCE_CHECK_ENABLED=false \
        bash "$DOTFILES_DIR/scripts/status.sh" --coach < /dev/null

    [ "$status" -eq 0 ]
    [[ "$output" == *"GitHub blindspots/opportunities (1-10):"* ]]
    [[ "$output" == *"Repo dotfiles likely wants one visible polish pass before new feature work."* ]]
    [[ "$output" != *"dir_usage_malformed=162"* ]]
    [[ "$output" != *"focus_git_status=diffuse proves"* ]]
    [[ "$output" != *"commit context (0)"* ]]
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
        AI_COACH_EVIDENCE_CHECK_ENABLED=true \
        bash "$DOTFILES_DIR/scripts/status.sh" --coach < /dev/null

    [ "$status" -eq 0 ]
    [[ "$output" == *"AI status coach was dispatcher missing; using deterministic fallback structure."* ]]
    [[ "$output" == *"Deterministic fallback (dispatcher missing)"* ]]
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
