#!/usr/bin/env bats

# test_goodevening_coach.sh - Bats coverage for goodevening coach.

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
    export PROJECTS_DIR="$TEST_ROOT/projects"
    mkdir -p "$DATA_DIR" "$DOTFILES_DIR/scripts/lib" "$DOTFILES_DIR/bin" "$PROJECTS_DIR"

    cp "$BATS_TEST_DIRNAME/../scripts/goodevening.sh" "$DOTFILES_DIR/scripts/goodevening.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/loader.sh" "$DOTFILES_DIR/scripts/lib/loader.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coach_ops.sh" "$DOTFILES_DIR/scripts/lib/coach_ops.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coach_metrics.sh" "$DOTFILES_DIR/scripts/lib/coach_metrics.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coach_prompts.sh" "$DOTFILES_DIR/scripts/lib/coach_prompts.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coach_scoring.sh" "$DOTFILES_DIR/scripts/lib/coach_scoring.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coaching.sh" "$DOTFILES_DIR/scripts/lib/coaching.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$DOTFILES_DIR/scripts/lib/config.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/date_utils.sh" "$DOTFILES_DIR/scripts/lib/date_utils.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/focus_relevance.sh" "$DOTFILES_DIR/scripts/lib/focus_relevance.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/health_ops.sh" "$DOTFILES_DIR/scripts/lib/health_ops.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/common.sh" "$DOTFILES_DIR/scripts/lib/common.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/file_ops.sh" "$DOTFILES_DIR/scripts/lib/file_ops.sh"
    chmod +x "$DOTFILES_DIR/scripts/goodevening.sh"

    cat > "$DOTFILES_DIR/scripts/data_validate.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$DOTFILES_DIR/scripts/data_validate.sh"

    cat > "$DOTFILES_DIR/scripts/backup_data.sh" <<'EOF'
#!/usr/bin/env bash
echo "backup ok"
exit 0
EOF
    chmod +x "$DOTFILES_DIR/scripts/backup_data.sh"

    cat > "$DOTFILES_DIR/bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$DATA_DIR/strategy_args_goodevening.txt"
cat > "$DATA_DIR/strategy_prompt_goodevening.txt"
cat <<'OUT'
Reflection Summary:
- Closed the day with one clear repo lane.
What worked:
- Focus stayed mostly inside the declared repo lane.
Off-script momentum:
- Switched contexts before closing the primary task.
What pulled you in:
- Open-ended tooling exploration after commit work.
Tomorrow lock:
- First move: start with one locked task.
- Done condition: ship one visible next step.
- Scope anchor boundary: stop side quests until the done condition.
Health lens:
- Work in two bounded blocks with a break.
OUT
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-strategy.sh"
    cat > "$DOTFILES_DIR/bin/dhp-coach.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/dhp-strategy.sh" "$@"
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-coach.sh"

    export TEST_DAY
    TEST_DAY="$(shift_date -1)"

    cat > "$DATA_DIR/todo_done.txt" <<EOF
$TEST_DAY 09:00:00|Completed primary task
EOF
    cat > "$DATA_DIR/journal.txt" <<EOF
$TEST_DAY 10:00:00|Kept focus for first block
EOF
    cat > "$DATA_DIR/daily_focus.txt" <<'EOF'
Ship one high-signal automation
EOF
    cat > "$DATA_DIR/health.txt" <<EOF
ENERGY|$TEST_DAY 09:00|5
FOG|$TEST_DAY 09:00|5
EOF
    cat > "$DATA_DIR/spoons.txt" <<EOF
BUDGET|$TEST_DAY|7
SPEND|$TEST_DAY|12:00|3|work|4
EOF
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "goodevening prompts for energy and fog before focus in interactive runs" {
    local runner="$TEST_ROOT/run_goodevening_with_tty.sh"
    local today

    today="$(date +%Y-%m-%d)"

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
export AI_REFLECTION_ENABLED=false
export AI_COACH_CHAT_ENABLED=false
export TEST_HEALTH_TIMESTAMP="$today 18:05"
/usr/bin/expect <<'EXPECT'
set timeout 20
spawn bash \$env(DOTFILES_DIR)/scripts/goodevening.sh --refresh
expect -re {Log Energy/Fog levels\\? \\[y/N\\]: $}
send -- "y\r"
expect -re {Energy Level \\(1-10\\): $}
send -- "5\r"
expect -re {Brain Fog Level \\(1-10\\): $}
send -- "4\r"
expect -re {TODAY'S FOCUS:}
expect eof
EXPECT
EOF
    chmod +x "$runner"

    run bash "$runner"

    [ "$status" -eq 0 ]
    grep -q "^ENERGY|$today 18:05|5\$" "$DATA_DIR/health.txt"
    grep -q "^FOG|$today 18:05|4\$" "$DATA_DIR/health.txt"
}

@test "goodevening collects one-line pre-brief answers before building the reflection prompt" {
    local runner="$TEST_ROOT/run_goodevening_prebrief_with_tty.sh"

    cat > "$runner" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export HOME="$HOME"
export DATA_DIR="$DATA_DIR"
export DOTFILES_DIR="$DOTFILES_DIR"
export PROJECTS_DIR="$PROJECTS_DIR"
export PATH="$DOTFILES_DIR/bin:\$PATH"
export AI_REFLECTION_ENABLED=true
export AI_COACH_CHAT_ENABLED=false
export AI_COACH_PREBRIEF_ALWAYS_ASK=true
export AI_COACH_PREBRIEF_MAX_QUESTIONS=3
/usr/bin/expect <<'EXPECT'
set timeout 20
spawn bash \$env(DOTFILES_DIR)/scripts/goodevening.sh --refresh $TEST_DAY
expect -re {PRE-BRIEF CHECK:}
expect -re {Pre-brief answers \[Enter to skip\]: $}
send -- "1A 2B 3E (keep it gentle)\r"
expect eof
EXPECT
EOF
    chmod +x "$runner"

    run bash "$runner"

    [ "$status" -eq 0 ]
    [ -f "$DATA_DIR/strategy_prompt_goodevening.txt" ]
    prompt="$(cat "$DATA_DIR/strategy_prompt_goodevening.txt")"
    [[ "$prompt" == *"Pre-brief clarifications:"* ]]
    [[ "$prompt" == *"- Framing: Valid exploration. Treat side work as part of the real pattern."* ]]
    [[ "$prompt" == *"- Lane: Current repo lane. Let recent repo or GitHub momentum lead the advice."* ]]
    [[ "$prompt" == *"- Pacing: custom - keep it gentle"* ]]
    [[ "$prompt" != *"PRE-BRIEF CHECK:"* ]]
}

@test "goodevening falls back to system date when startday marker is missing" {
    rm -f "$DATA_DIR/current_day"
    expected_today="$(date +%Y-%m-%d)"

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        AI_REFLECTION_ENABLED=false \
        bash "$DOTFILES_DIR/scripts/goodevening.sh" < /dev/null

    [ "$status" -eq 0 ]
    [[ "$output" == *"Evening Close-Out for $expected_today"* ]]
    grep -q "startday marker missing; using system date $expected_today" "$DATA_DIR/system.log"
}

@test "goodevening hides inactive repos from recent pushes and shows the reactivation list" {
    local repos_fixture="$TEST_ROOT/repos.json"
    local today
    local now_utc_iso

    today="$(date +%Y-%m-%d)"
    now_utc_iso="$(python3 - <<'PY'
from datetime import datetime, timezone

print(datetime.now().astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/github_ops.sh" "$DOTFILES_DIR/scripts/lib/github_ops.sh"
    cat > "$DOTFILES_DIR/scripts/github_helper.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    list_repos)
        if [[ -n "${GITHUB_REPOS_FIXTURE:-}" ]] && [[ -f "$GITHUB_REPOS_FIXTURE" ]]; then
            cat "$GITHUB_REPOS_FIXTURE"
        else
            echo "[]"
        fi
        ;;
    list_commits_for_date)
        exit 0
        ;;
esac
EOF
    chmod +x "$DOTFILES_DIR/scripts/github_helper.sh"

    cat > "$repos_fixture" <<EOF
[
  {"name":"dotfiles","pushed_at":"${now_utc_iso}"},
  {"name":"rockit","pushed_at":"${now_utc_iso}"}
]
EOF
    printf '%s\n' "dotfiles|${today}|good place" > "$DATA_DIR/github_inactive_repos.txt"

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        GITHUB_REPOS_FIXTURE="$repos_fixture" \
        AI_REFLECTION_ENABLED=false \
        AI_COACH_CHAT_ENABLED=false \
        bash -c "$DOTFILES_DIR/scripts/goodevening.sh --refresh $TEST_DAY < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"rockit (pushed today)"* ]]
    [[ "$output" != *"dotfiles (pushed today)"* ]]
    [[ "$output" == *"⏸️ INACTIVE REPOS (reactivate to track again):"* ]]
    [[ "$output" == *"dotfiles (inactive ${today} - good place)"* ]]
}

@test "goodevening ignores stale startday marker older than 24 hours" {
    printf '%s\n' "$(shift_date -30)" > "$DATA_DIR/current_day"
    python3 - "$DATA_DIR/current_day" <<'PY'
import os
import sys
import time

stale_epoch = int(time.time()) - (3 * 24 * 60 * 60)
os.utime(sys.argv[1], (stale_epoch, stale_epoch))
PY
    expected_today="$(date +%Y-%m-%d)"

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        AI_REFLECTION_ENABLED=false \
        bash "$DOTFILES_DIR/scripts/goodevening.sh" < /dev/null

    [ "$status" -eq 0 ]
    [[ "$output" == *"Evening Close-Out for $expected_today"* ]]
    grep -q "stale current_day marker" "$DATA_DIR/system.log"
}

@test "goodevening reflection prompt uses reflective schema" {
    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        AI_REFLECTION_ENABLED=true \
        AI_COACH_LOG_ENABLED=true \
        AI_COACH_MODE_DEFAULT=LOCKED \
        bash -c "$DOTFILES_DIR/scripts/goodevening.sh --refresh $TEST_DAY < /dev/null"

    [ "$status" -eq 0 ]
    [ -f "$DATA_DIR/strategy_prompt_goodevening.txt" ]
    [ -f "$DATA_DIR/strategy_args_goodevening.txt" ]

    prompt="$(cat "$DATA_DIR/strategy_prompt_goodevening.txt")"
    args="$(cat "$DATA_DIR/strategy_args_goodevening.txt")"

    [[ "$prompt" == *"Coach mode used today:"* ]]
    [[ "$prompt" == *"Behavior digest:"* ]]
    [[ "$prompt" == *"Wearable guidance:"* ]]
    [[ "$prompt" == *"Additional local context bundle:"* ]]
    [[ "$prompt" == *"Raw journal entries (last 7 days):"* ]]
    [[ "$prompt" == *"Blindspots to sleep on (1-5):"* ]]
    [[ "$prompt" == *"Tomorrow lock:"* ]]
    [[ "$prompt" == *"Health lens:"* ]]
    [[ "$prompt" == *"Make the main verdict about whether the spear moved, stalled, or diffused based on focus plus available GitHub or strategy evidence"* ]]
    [[ "$args" == *"--temperature"* ]]

    [[ "$output" == *"What worked:"* ]]
    [[ "$output" == *"Off-script momentum:"* ]]
    [[ "$output" == *"Tomorrow lock:"* ]]

    # Signal metadata line includes confidence and reason summary
    [[ "$output" == *"(Signal:"*" - "*")"* ]]

    [ -f "$DATA_DIR/coach_log.txt" ]
    grep -q '^GOODEVENING|' "$DATA_DIR/coach_log.txt"
}

@test "goodevening reuses a completed focus from today's history when the active focus was cleared" {
    rm -f "$DATA_DIR/daily_focus.txt"
    cat > "$DATA_DIR/focus_history.log" <<EOF
$TEST_DAY|Ship one high-signal automation
EOF

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        AI_REFLECTION_ENABLED=true \
        AI_COACH_CHAT_ENABLED=false \
        bash -c "$DOTFILES_DIR/scripts/goodevening.sh --refresh $TEST_DAY < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Ship one high-signal automation (completed earlier today)"* ]]
    [[ "$output" != *"(No focus set)"* ]]

    prompt="$(cat "$DATA_DIR/strategy_prompt_goodevening.txt")"
    [[ "$prompt" == *"Today's focus:"*$'\n'"Ship one high-signal automation"* ]]
}

@test "goodevening auto-syncs Fitbit data before reflection when auth exists" {
    cat > "$DOTFILES_DIR/scripts/fitbit_sync.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$DATA_DIR/fitbit_sync_args_goodevening.txt"
EOF
    chmod +x "$DOTFILES_DIR/scripts/fitbit_sync.sh"
    printf '%s\n' '{"refresh_token":"test"}' > "$DATA_DIR/google_health_oauth.json"

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        AI_REFLECTION_ENABLED=false \
        GOOGLE_HEALTH_DEFAULT_DAYS=14 \
        bash -c "$DOTFILES_DIR/scripts/goodevening.sh --refresh $TEST_DAY < /dev/null"

    [ "$status" -eq 0 ]
    [ -f "$DATA_DIR/fitbit_sync_args_goodevening.txt" ]
    [[ "$(cat "$DATA_DIR/fitbit_sync_args_goodevening.txt")" == "sync 14" ]]
}

@test "goodevening uses deterministic fallback when strategy call times out" {
    cat > "$DOTFILES_DIR/bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
sleep 3
echo "late reflection"
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-strategy.sh"

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        AI_REFLECTION_ENABLED=true \
        AI_COACH_LOG_ENABLED=true \
        AI_COACH_MODE_DEFAULT=LOCKED \
        AI_COACH_REQUEST_TIMEOUT_SECONDS=1 \
        AI_COACH_RETRY_ON_TIMEOUT=false \
        bash -c "$DOTFILES_DIR/scripts/goodevening.sh --refresh $TEST_DAY < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"What worked:"* ]]
    [[ "$output" == *"Off-script momentum:"* ]]
    [[ "$output" == *"What pulled you in:"* ]]
    [[ "$output" == *"Tomorrow lock:"* ]]
    [[ "$output" == *"AI reflection was timeout; using deterministic fallback structure."* ]]
    [[ "$output" != *"top task aligned to focus"* ]]
}

@test "goodevening retries after timeout and returns AI output when retry succeeds" {
    cat > "$DOTFILES_DIR/bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
sleep 2
cat <<'OUT'
Reflection Summary:
- Retry delivered output.
What worked:
- Retry delivered output.
Off-script momentum:
- Context switching.
What pulled you in:
- Open loops.
Tomorrow lock:
- First move: resume one repo lane.
- Done condition: ship one visible next step.
- Scope anchor boundary: no side quests before the first block lands.
Health lens:
- Pace blocks.
OUT
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-strategy.sh"

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        AI_REFLECTION_ENABLED=true \
        AI_COACH_LOG_ENABLED=true \
        AI_COACH_MODE_DEFAULT=LOCKED \
        AI_COACH_REQUEST_TIMEOUT_SECONDS=1 \
        AI_COACH_RETRY_ON_TIMEOUT=true \
        AI_COACH_RETRY_TIMEOUT_SECONDS=4 \
        bash -c "$DOTFILES_DIR/scripts/goodevening.sh --refresh $TEST_DAY < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Retry delivered output."* ]]
    [[ "$output" != *"Deterministic fallback (timeout)"* ]]
}

@test "goodevening filters noisy AI blindspots when the dispatcher returns output" {
    cat > "$DOTFILES_DIR/bin/dhp-strategy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'OUT'
Reflection Summary:
- Closed the day with one clear repo lane.
Blindspots to sleep on (1-10):
1. dir_usage_malformed=162 means your tracking stack is unstable.
2. focus_git_status=diffuse proves the spear is broken.
3. commit_context data is absent so the pattern is unknowable.
4. High brain fog score suggests a mismatch between cognitive load and capacity.
5. Low suggestion adherence rate implies planned interventions are being ignored.
6. The afternoon slump is likely derailing any complex planning work.
7. The upward completion trend is positive but based on only one recent task.
8. The lack of commit context (0) means we cannot verify whether the work is only local.
9. Keep the repo lane visible to future you.
What worked:
- Focus stayed mostly inside the declared repo lane.
Off-script momentum:
- Switched contexts before closing the primary task.
What pulled you in:
- Open-ended tooling exploration after commit work.
Tomorrow lock:
- First move: start with one locked task.
- Done condition: ship one visible next step.
- Scope anchor boundary: stop side quests until the done condition.
Health lens:
- Work in two bounded blocks with a break.
OUT
EOF
    chmod +x "$DOTFILES_DIR/bin/dhp-strategy.sh"

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        AI_REFLECTION_ENABLED=true \
        AI_COACH_LOG_ENABLED=true \
        AI_COACH_MODE_DEFAULT=LOCKED \
        AI_COACH_REQUEST_TIMEOUT_SECONDS=5 \
        AI_COACH_RETRY_ON_TIMEOUT=false \
        bash -c "$DOTFILES_DIR/scripts/goodevening.sh --refresh $TEST_DAY < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Blindspots to sleep on (1-5):"* ]]
    [[ "$output" != *"dir_usage_malformed=162 means your tracking stack is unstable."* ]]
    [[ "$output" != *"focus_git_status=diffuse proves the spear is broken."* ]]
    [[ "$output" != *"commit_context data is absent so the pattern is unknowable."* ]]
    [[ "$output" == *"1. Keep the repo lane visible to future you."* ]]
}

@test "goodevening summarizes project safety findings with a detail cap" {
    local repo

    for repo in alpha beta gamma; do
        mkdir -p "$PROJECTS_DIR/$repo"
        git -C "$PROJECTS_DIR/$repo" init >/dev/null 2>&1
        cat > "$PROJECTS_DIR/$repo/README.md" <<EOF
$repo
EOF
        git -C "$PROJECTS_DIR/$repo" add README.md >/dev/null 2>&1
        git -C "$PROJECTS_DIR/$repo" -c user.name=Test -c user.email=test@example.com commit -m "init" >/dev/null 2>&1
        printf '%s\n' "dirty $repo" >> "$PROJECTS_DIR/$repo/README.md"
    done

    run env \
        PATH="$DOTFILES_DIR/bin:$PATH" \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        AI_REFLECTION_ENABLED=false \
        GOODEVENING_PROJECT_SCAN_LIMIT=10 \
        GOODEVENING_PROJECT_ISSUE_DETAIL_LIMIT=1 \
        bash -c "$DOTFILES_DIR/scripts/goodevening.sh --refresh $TEST_DAY < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"🚀 PROJECT SAFETY CHECK:"* ]]
    [[ "$output" == *"3 project(s) with safety issues across 3 scanned repo(s)"* ]]
    [[ "$output" == *"2 more project(s) not shown"* ]]
}
