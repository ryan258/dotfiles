#!/usr/bin/env bats

# test_observer_v2.sh - Bats coverage for V2 projects, workflows, and graph checks.

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    OBSERVER_SCRIPT="$BATS_TEST_DIRNAME/../scripts/observer.sh"
    export OBSIDIAN_VAULT="$TEST_DIR/vault"
    REPO="$TEST_DIR/dotfiles"
    mkdir -p "$REPO"
    git -C "$REPO" init >/dev/null
    git -C "$REPO" config user.email "test@example.com"
    git -C "$REPO" config user.name "Test User"
}

teardown() {
    teardown_test_environment
}

write_event_day() {
    local day="$1"
    mkdir -p "$OBSIDIAN_VAULT/raw/events"
    cat > "$OBSIDIAN_VAULT/raw/events/$day.jsonl" <<JSONL
{"command":"startday.sh","command_key":"startday","cwd":"$REPO","duration_ms":100,"event":"command","exit_code":0,"schema":1,"ts":"${day}T09:00:00-05:00"}
{"command":"status.sh --coach","command_key":"status","cwd":"$REPO","duration_ms":100,"event":"command","exit_code":0,"schema":1,"ts":"${day}T09:10:00-05:00"}
{"command":"focus set dotfiles","command_key":"focus","cwd":"$REPO","duration_ms":100,"event":"command","exit_code":0,"schema":1,"ts":"${day}T09:20:00-05:00"}
JSONL
}

@test "observer init-vault creates V2 graph structure and repo daily block" {
    run "$OBSERVER_SCRIPT" init-vault
    [ "$status" -eq 0 ]
    assert_file_exists "$OBSIDIAN_VAULT/maps/project-index.md"
    assert_file_exists "$OBSIDIAN_VAULT/maps/workflow-index.md"
    [ -d "$OBSIDIAN_VAULT/wiki/projects" ]
    [ -d "$OBSIDIAN_VAULT/wiki/workflows" ]
    [ -d "$OBSIDIAN_VAULT/wiki/concepts" ]

    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-11
    [ "$status" -eq 0 ]
    assert_file_contains "$OBSIDIAN_VAULT/daily/2026-05-11.md" "<!-- observer:start repos -->"
}

@test "observer digest writes repo markers and project candidates from three daily appearances" {
    for day in 2026-05-09 2026-05-10 2026-05-11; do
        write_event_day "$day"
        run "$OBSERVER_SCRIPT" digest "$day"
        [ "$status" -eq 0 ]
    done

    grep -Fq -- "- Repo: \`$REPO\`" "$OBSIDIAN_VAULT/daily/2026-05-11.md"
    grep -Fq -- "[candidate] \`$REPO\`" "$OBSIDIAN_VAULT/maps/project-index.md"
    grep -Fq -- "startday -> status -> focus" "$OBSIDIAN_VAULT/maps/workflow-index.md"
}

@test "project-note creates a project hub and observer-managed blocks" {
    write_event_day 2026-05-11
    run "$OBSERVER_SCRIPT" digest 2026-05-11
    [ "$status" -eq 0 ]

    run "$OBSERVER_SCRIPT" project-note "$REPO" --date 2026-05-11 --description "Personal operating system."
    [ "$status" -eq 0 ]
    project_path="$output"
    assert_file_exists "$project_path"
    assert_file_contains "$project_path" "type: project"
    assert_file_contains "$project_path" "repo: $REPO"
    grep -Fq -- "[[wiki/commands/startday|startday]]" "$project_path"
    grep -Fq -- "[[wiki/projects/dotfiles|dotfiles]]" "$OBSIDIAN_VAULT/maps/project-index.md"
}

@test "workflow-note creates an exact command-sequence workflow" {
    mkdir -p "$OBSIDIAN_VAULT/wiki/commands"
    touch "$OBSIDIAN_VAULT/wiki/commands/startday.md"
    touch "$OBSIDIAN_VAULT/wiki/commands/status.md"
    touch "$OBSIDIAN_VAULT/wiki/commands/focus.md"
    for day in 2026-05-09 2026-05-10 2026-05-11; do
        write_event_day "$day"
        run "$OBSERVER_SCRIPT" digest "$day"
        [ "$status" -eq 0 ]
    done

    run "$OBSERVER_SCRIPT" workflow-note --sequence "startday,status,focus" --repo "$REPO" --date 2026-05-11
    [ "$status" -eq 0 ]
    workflow_path="$output"
    assert_file_exists "$workflow_path"
    grep -Fq -- "[[wiki/commands/startday|startday]] -> [[wiki/commands/status|status]] -> [[wiki/commands/focus|focus]]" "$workflow_path"
    grep -Fq -- "[[daily/2026-05-11|2026-05-11]]" "$workflow_path"
    grep -Fq -- "[[wiki/workflows/startday-status-focus|startday -> status -> focus]]" "$OBSIDIAN_VAULT/maps/workflow-index.md"
}

@test "graph reports project and workflow candidates" {
    for day in 2026-05-09 2026-05-10 2026-05-11; do
        write_event_day "$day"
        run "$OBSERVER_SCRIPT" digest "$day"
        [ "$status" -eq 0 ]
    done

    run "$OBSERVER_SCRIPT" graph candidates --date 2026-05-11
    [ "$status" -eq 0 ]
    [[ "$output" == *"$REPO"* ]]
    [[ "$output" == *"startday -> status -> focus"* ]]
}
