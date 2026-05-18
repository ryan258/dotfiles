#!/usr/bin/env bats

# test_optional_product_degradation.sh - Smoke tests for optional product wrappers.

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    export TEST_ROOT
    TEST_ROOT="$(mktemp -d)"
    export HOME="$TEST_ROOT/home"
    export DATA_DIR="$HOME/.config/dotfiles-data"
    export DOTFILES_DIR="$TEST_ROOT/dotfiles"
    export PROJECTS_DIR="$TEST_ROOT/projects"
    export TODAY
    TODAY="$(date +%Y-%m-%d)"

    mkdir -p "$DATA_DIR" "$DOTFILES_DIR/scripts/lib" "$DOTFILES_DIR/bin" "$PROJECTS_DIR" "$TEST_ROOT/bin"

    cp "$BATS_TEST_DIRNAME/../scripts/startday.sh" "$DOTFILES_DIR/scripts/startday.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/status.sh" "$DOTFILES_DIR/scripts/status.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/goodevening.sh" "$DOTFILES_DIR/scripts/goodevening.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/"*.sh "$DOTFILES_DIR/scripts/lib/"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/"*.py "$DOTFILES_DIR/scripts/lib/" 2>/dev/null || true
    chmod +x "$DOTFILES_DIR/scripts/startday.sh" "$DOTFILES_DIR/scripts/status.sh" "$DOTFILES_DIR/scripts/goodevening.sh"

    cp "$BATS_TEST_DIRNAME/../bin/cyborg" "$DOTFILES_DIR/bin/cyborg"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-tech.sh" "$DOTFILES_DIR/bin/dhp-tech.sh"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-shared.sh" "$DOTFILES_DIR/bin/dhp-shared.sh"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-lib.sh" "$DOTFILES_DIR/bin/dhp-lib.sh"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-utils.sh" "$DOTFILES_DIR/bin/dhp-utils.sh"
    chmod +x "$DOTFILES_DIR/bin/cyborg" "$DOTFILES_DIR/bin/dhp-tech.sh"

    cat > "$DOTFILES_DIR/scripts/todo.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "  1. Test task"
STUB
    chmod +x "$DOTFILES_DIR/scripts/todo.sh"

    cat > "$DOTFILES_DIR/scripts/data_validate.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
exit 0
STUB
    chmod +x "$DOTFILES_DIR/scripts/data_validate.sh"

    cat > "$DOTFILES_DIR/scripts/backup_data.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "backup ok"
STUB
    chmod +x "$DOTFILES_DIR/scripts/backup_data.sh"

    cat > "$DOTFILES_DIR/scripts/observer.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "Traceback (most recent call last): observer unavailable" >&2
exit 42
STUB
    chmod +x "$DOTFILES_DIR/scripts/observer.sh"

    cat > "$TEST_ROOT/bin/curl" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
    chmod +x "$TEST_ROOT/bin/curl"

    cat > "$TEST_ROOT/bin/jq" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
    chmod +x "$TEST_ROOT/bin/jq"

    cat > "$TEST_ROOT/bin/uv" <<'STUB'
#!/usr/bin/env bash
cat >/dev/null
echo "uv should not run when AI Staff HQ is missing" >&2
exit 9
STUB
    chmod +x "$TEST_ROOT/bin/uv"

    cat > "$DATA_DIR/current_day" <<EOF
$TODAY
EOF
    cat > "$DATA_DIR/daily_focus.txt" <<'EOF'
Keep the daily loop stable
EOF
    cat > "$DATA_DIR/todo_done.txt" <<EOF
$TODAY 09:00:00|Kept command surface stable
EOF
    cat > "$DATA_DIR/journal.txt" <<EOF
$TODAY 10:00:00|Optional product smoke test fixture
EOF
    cat > "$DATA_DIR/health.txt" <<EOF
ENERGY|$TODAY 09:00|5
FOG|$TODAY 09:00|4
EOF
    cat > "$DATA_DIR/spoons.txt" <<EOF
BUDGET|$TODAY|7
SPEND|$TODAY|11:00|1|test setup|6
EOF
}

teardown() {
    rm -rf "$TEST_ROOT"
}

run_with_missing_optional_products() {
    env \
        HOME="$HOME" \
        DATA_DIR="$DATA_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        PATH="$TEST_ROOT/bin:$DOTFILES_DIR/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        OBSIDIAN_DAILY_ENABLED=true \
        OBSERVER_HOME="$TEST_ROOT/missing/observer-home" \
        OBSIDIAN_VAULT="$TEST_ROOT/missing/obsidian-vault" \
        CYBORG_HOME="$TEST_ROOT/missing/cyborg-agent" \
        CYBORG_LAB_DIR="$TEST_ROOT/missing/cyborg-lab" \
        AI_STAFF_DIR="$TEST_ROOT/missing/ai-staff-hq" \
        AI_BRIEFING_ENABLED=false \
        AI_REFLECTION_ENABLED=false \
        AI_STATUS_ENABLED=false \
        AI_COACH_CHAT_ENABLED=false \
        OPENROUTER_API_KEY=test-key \
        DHP_TECH_OUTPUT_DIR="$DATA_DIR/dhp-output" \
        "$@" < /dev/null
}

assert_no_stack_trace() {
    local text="$1"

    [[ "$text" != *"Traceback"* ]]
    [[ "$text" != *"unbound variable"* ]]
    [[ "$text" != *"uv should not run when AI Staff HQ is missing"* ]]
}

@test "startday ignores failing observer hook without surfacing a stack trace" {
    run run_with_missing_optional_products bash "$DOTFILES_DIR/scripts/startday.sh" refresh

    [ "$status" -eq 0 ]
    [[ "$output" == *"HEALTH CHECK"* ]]
    assert_no_stack_trace "$output"
}

@test "status exits cleanly with optional product paths missing" {
    run run_with_missing_optional_products bash "$DOTFILES_DIR/scripts/status.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"WHERE YOU ARE"* ]]
    assert_no_stack_trace "$output"
}

@test "goodevening exits cleanly with optional product paths missing" {
    run run_with_missing_optional_products bash "$DOTFILES_DIR/scripts/goodevening.sh" --refresh

    [ "$status" -eq 0 ]
    [[ "$output" == *"Evening wrap-up complete"* ]]
    assert_no_stack_trace "$output"
}

@test "dhp dispatcher reports missing AI Staff HQ without a stack trace" {
    run run_with_missing_optional_products bash "$DOTFILES_DIR/bin/dhp-tech.sh" "Summarize the stable wrapper contract"

    [ "$status" -ne 0 ]
    [[ "$output" == *"AI Staff HQ unavailable"* ]]
    [[ "$output" == *"$TEST_ROOT/missing/ai-staff-hq"* ]]
    assert_no_stack_trace "$output"
}

@test "cyborg wrapper help reports missing sibling repo after Phase 8" {
    skip "Phase 8: bin/cyborg --help reports missing CYBORG_HOME without failing"

    run run_with_missing_optional_products bash "$DOTFILES_DIR/bin/cyborg" --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Cyborg agent is unavailable"* ]]
    assert_no_stack_trace "$output"
}

@test "cyborg wrapper action fails when sibling repo is missing after Phase 8" {
    skip "Phase 8: cyborg action commands report missing CYBORG_HOME and exit non-zero"

    run run_with_missing_optional_products bash "$DOTFILES_DIR/bin/cyborg" auto --yes "test wrapper degradation"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Cyborg agent is unavailable"* ]]
    assert_no_stack_trace "$output"
}
