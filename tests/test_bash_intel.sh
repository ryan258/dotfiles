#!/usr/bin/env bats

# test_bash_intel.sh - Bats coverage for bash_intel shell intelligence wrapper.

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    export REPO_ROOT
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    mkdir -p "$TEST_DIR/bin" "$TEST_DIR/work"
    export BASH_INTEL_CLIENT="$TEST_DIR/bin/fake_bash_intel_client"
    cat > "$BASH_INTEL_CLIENT" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'client:'
for arg in "$@"; do
    printf ' [%s]' "$arg"
done
printf '\n'
STUB
    chmod +x "$BASH_INTEL_CLIENT"

    cat > "$TEST_DIR/work/sample.sh" <<'SHELL'
#!/usr/bin/env bash
hello_world() {
    printf 'hello\n'
}
SHELL
}

teardown() {
    teardown_test_environment
}

@test "bash_intel check delegates to configured client" {
    run "$REPO_ROOT/scripts/bash_intel.sh" check

    [ "$status" -eq 0 ]
    [[ "$output" == "client: [check]" ]]
}

@test "bash_intel symbols validates and canonicalizes file paths" {
    run "$REPO_ROOT/scripts/bash_intel.sh" symbols "$TEST_DIR/work/sample.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == "client: [symbols] [$TEST_DIR/work/sample.sh]" ]]
}

@test "bash_intel definition requires a symbol" {
    run "$REPO_ROOT/scripts/bash_intel.sh" definition

    [ "$status" -eq 2 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "bash_intel symbols rejects paths outside HOME" {
    run "$REPO_ROOT/scripts/bash_intel.sh" symbols /etc/passwd

    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid shell file path"* ]]
}
