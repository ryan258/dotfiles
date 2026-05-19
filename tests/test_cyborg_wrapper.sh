#!/usr/bin/env bats

# test_cyborg_wrapper.sh - Compatibility wrapper coverage for extracted Cyborg.

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    setup_test_environment
    export DOTFILES_DIR="$TEST_DIR/dotfiles"
    export PROJECTS_DIR="$TEST_DIR/Projects"
    export CYBORG_HOME="$PROJECTS_DIR/cyborg-agent"

    mkdir -p "$DOTFILES_DIR/bin" "$DOTFILES_DIR/scripts/lib" "$PROJECTS_DIR"
    cp "$BATS_TEST_DIRNAME/../bin/cyborg" "$DOTFILES_DIR/bin/cyborg"
    cp "$BATS_TEST_DIRNAME/../bin/cyborg-sync" "$DOTFILES_DIR/bin/cyborg-sync"
    cp "$BATS_TEST_DIRNAME/../scripts/cyborg_scoped_site_check.sh" "$DOTFILES_DIR/scripts/cyborg_scoped_site_check.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$DOTFILES_DIR/scripts/lib/config.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/common.sh" "$DOTFILES_DIR/scripts/lib/common.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/file_ops.sh" "$DOTFILES_DIR/scripts/lib/file_ops.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/wrapper_common.sh" "$DOTFILES_DIR/scripts/lib/wrapper_common.sh"
    chmod +x "$DOTFILES_DIR/bin/cyborg" "$DOTFILES_DIR/bin/cyborg-sync" "$DOTFILES_DIR/scripts/cyborg_scoped_site_check.sh"
}

@test "cyborg wrappers in source tree retain executable bit" {
    [ -x "$BATS_TEST_DIRNAME/../bin/cyborg" ]
    [ -x "$BATS_TEST_DIRNAME/../bin/cyborg-sync" ]
    [ -x "$BATS_TEST_DIRNAME/../scripts/cyborg_scoped_site_check.sh" ]
}

teardown() {
    teardown_test_environment
}

run_cyborg_wrapper() {
    env \
        HOME="$TEST_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        CYBORG_HOME="$CYBORG_HOME" \
        "$DOTFILES_DIR/bin/cyborg" "$@"
}

run_cyborg_sync_wrapper() {
    env \
        HOME="$TEST_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        CYBORG_HOME="$CYBORG_HOME" \
        "$DOTFILES_DIR/bin/cyborg-sync" "$@"
}

run_cyborg_site_check_wrapper() {
    env \
        HOME="$TEST_DIR" \
        DOTFILES_DIR="$DOTFILES_DIR" \
        PROJECTS_DIR="$PROJECTS_DIR" \
        CYBORG_HOME="$CYBORG_HOME" \
        "$DOTFILES_DIR/scripts/cyborg_scoped_site_check.sh" "$@"
}

@test "cyborg wrapper delegates to sibling repo implementation" {
    mkdir -p "$CYBORG_HOME/scripts"
    cat > "$CYBORG_HOME/scripts/cyborg_agent.py" <<'PY'
import os
import sys

print("cyborg helper:", " ".join(sys.argv[1:]))
print("user cwd:", os.environ.get("USER_CWD", ""))
PY

    run run_cyborg_wrapper ingest --repo "$TEST_DIR/source"

    [ "$status" -eq 0 ]
    [[ "$output" == *"cyborg helper: ingest --repo $TEST_DIR/source"* ]]
    [[ "$output" == *"user cwd:"* ]]
}

@test "cyborg wrapper reports missing sibling repo for direct commands" {
    run run_cyborg_wrapper auto --yes "test wrapper degradation"

    [ "$status" -eq 3 ]
    [[ "$output" == *"Cyborg agent is unavailable"* ]]
    [[ "$output" == *"$CYBORG_HOME"* ]]
    [[ "$output" != *"Traceback"* ]]
}

@test "cyborg wrapper help reports missing sibling repo without failing" {
    run run_cyborg_wrapper --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Cyborg agent is unavailable"* ]]
    [[ "$output" == *"$CYBORG_HOME"* ]]
    [[ "$output" != *"Traceback"* ]]
}

@test "cyborg-sync wrapper delegates to sibling repo implementation" {
    mkdir -p "$CYBORG_HOME/scripts"
    cat > "$CYBORG_HOME/scripts/cyborg_docs_sync.py" <<'PY'
import sys

print("cyborg-sync helper:", " ".join(sys.argv[1:]))
PY

    run run_cyborg_sync_wrapper --repo "$TEST_DIR/source" plan

    [ "$status" -eq 0 ]
    [[ "$output" == *"cyborg-sync helper: --repo $TEST_DIR/source plan"* ]]
}

@test "cyborg-sync wrapper reports missing sibling repo for direct commands" {
    run run_cyborg_sync_wrapper --repo "$TEST_DIR/source" plan

    [ "$status" -eq 3 ]
    [[ "$output" == *"Cyborg docs sync is unavailable"* ]]
    [[ "$output" == *"$CYBORG_HOME"* ]]
    [[ "$output" != *"Traceback"* ]]
}

@test "cyborg-sync wrapper nested help reports missing sibling repo without failing" {
    run run_cyborg_sync_wrapper plan --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Cyborg docs sync is unavailable"* ]]
    [[ "$output" == *"$CYBORG_HOME"* ]]
}

@test "cyborg scoped site check wrapper delegates to sibling repo implementation" {
    mkdir -p "$CYBORG_HOME/scripts"
    cat > "$CYBORG_HOME/scripts/cyborg_scoped_site_check.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "scoped check helper: $*"
SH
    chmod +x "$CYBORG_HOME/scripts/cyborg_scoped_site_check.sh"

    run run_cyborg_site_check_wrapper content/projects/example.md

    [ "$status" -eq 0 ]
    [[ "$output" == *"scoped check helper: content/projects/example.md"* ]]
}

@test "cyborg scoped site check wrapper reports missing sibling repo" {
    run run_cyborg_site_check_wrapper content/projects/example.md

    [ "$status" -eq 3 ]
    [[ "$output" == *"Cyborg scoped site check is unavailable"* ]]
    [[ "$output" == *"$CYBORG_HOME"* ]]
}

@test "cyborg scoped site check wrapper help reports missing sibling repo without failing" {
    run run_cyborg_site_check_wrapper --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Cyborg scoped site check is unavailable"* ]]
    [[ "$output" == *"$CYBORG_HOME"* ]]
}

@test "cyborg scoped site check wrapper rejects unsafe content paths before delegation" {
    mkdir -p "$CYBORG_HOME/scripts"
    cat > "$CYBORG_HOME/scripts/cyborg_scoped_site_check.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "should not delegate"
SH
    chmod +x "$CYBORG_HOME/scripts/cyborg_scoped_site_check.sh"

    run run_cyborg_site_check_wrapper ../secrets.md

    [ "$status" -eq 2 ]
    [[ "$output" == *"Scoped site check only accepts content/ paths"* ]]
    [[ "$output" != *"should not delegate"* ]]

    run run_cyborg_site_check_wrapper content/../secrets.md

    [ "$status" -eq 2 ]
    [[ "$output" == *"must not contain '..'"* ]]
    [[ "$output" != *"should not delegate"* ]]
}
