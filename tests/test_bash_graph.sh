#!/usr/bin/env bats

# test_bash_graph.sh - Bats coverage for shell dependency graph tooling.

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    export REPO_ROOT
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    export FIXTURE_ROOT="$TEST_DIR/repo"
    mkdir -p "$FIXTURE_ROOT/bin" "$FIXTURE_ROOT/scripts/lib" "$FIXTURE_ROOT/zsh" "$FIXTURE_ROOT/tests"

    cat > "$FIXTURE_ROOT/scripts/lib/common.sh" <<'SHELL'
#!/usr/bin/env bash
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

sanitize_input() {
    printf '%s\n' "$1"
}

validate_path() {
    printf '%s\n' "$1"
}
SHELL

    cat > "$FIXTURE_ROOT/scripts/tool.sh" <<'SHELL'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

tool_main() {
    local target
    target=$(validate_path "$1")
    sanitize_input "$target"
}

tool_main "$@"
SHELL

    cat > "$FIXTURE_ROOT/bin/dhp-shared.sh" <<'SHELL'
#!/usr/bin/env bash
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

dhp_dispatch() {
    printf '%s\n' "$1"
}
SHELL

    cat > "$FIXTURE_ROOT/bin/dhp-demo.sh" <<'SHELL'
#!/usr/bin/env bash
set -euo pipefail
    source	"$(dirname "$0")/dhp-shared.sh"

dhp_dispatch "demo"
SHELL

    cat > "$FIXTURE_ROOT/zsh/aliases.zsh" <<'SHELL'
alias tool='scripts/tool.sh'
SHELL

    cat > "$FIXTURE_ROOT/tests/test_tool.sh" <<'SHELL'
#!/usr/bin/env bats

@test "tool validates path" {
    run "$BATS_TEST_DIRNAME/../scripts/tool.sh" value
    [ "$status" -eq 0 ]
}
SHELL

    cat > "$FIXTURE_ROOT/tests/fixture_writer.sh" <<'SHELL'
#!/usr/bin/env bash
cat > generated.sh <<'GENERATED'
fake_helper() {
    validate_path "$1"
}
GENERATED
SHELL
}

teardown() {
    teardown_test_environment
}

@test "bash_graph scan records functions sources references and aliases" {
    run env BASH_GRAPH_ROOT="$FIXTURE_ROOT" "$REPO_ROOT/scripts/bash_graph.sh" scan

    [ "$status" -eq 0 ]
    [[ "$output" == *'"path": "scripts/tool.sh"'* ]]
    [[ "$output" == *'"name": "tool_main"'* ]]
    [[ "$output" == *'"source": "scripts/tool.sh"'* ]]
    [[ "$output" == *'"target": "scripts/lib/common.sh"'* ]]
    [[ "$output" == *'"source": "bin/dhp-demo.sh"'* ]]
    [[ "$output" == *'"target": "bin/dhp-shared.sh"'* ]]
    [[ "$output" == *'"symbol": "validate_path"'* ]]
    [[ "$output" == *'"alias": "tool"'* ]]
    [[ "$output" != *'"name": "fake_helper"'* ]]
}

@test "bash_graph sources lists resolved sourced files" {
    run env BASH_GRAPH_ROOT="$FIXTURE_ROOT" "$REPO_ROOT/scripts/bash_graph.sh" sources scripts/tool.sh

    [ "$status" -eq 0 ]
    [[ "$output" == *'"command": "sources"'* ]]
    [[ "$output" == *'"target": "scripts/lib/common.sh"'* ]]
}

@test "bash_graph dependents lists files that source a library" {
    run env BASH_GRAPH_ROOT="$FIXTURE_ROOT" "$REPO_ROOT/scripts/bash_graph.sh" dependents scripts/lib/common.sh

    [ "$status" -eq 0 ]
    [[ "$output" == *'"command": "dependents"'* ]]
    [[ "$output" == *'"source": "scripts/tool.sh"'* ]]
}

@test "bash_graph functions lists definitions for a symbol" {
    run env BASH_GRAPH_ROOT="$FIXTURE_ROOT" "$REPO_ROOT/scripts/bash_graph.sh" functions validate_path

    [ "$status" -eq 0 ]
    [[ "$output" == *'"command": "functions"'* ]]
    [[ "$output" == *'"symbol": "validate_path"'* ]]
    [[ "$output" == *'"file": "scripts/lib/common.sh"'* ]]
}

@test "bash_graph impact reports definitions and references for a symbol" {
    run env BASH_GRAPH_ROOT="$FIXTURE_ROOT" "$REPO_ROOT/scripts/bash_graph.sh" impact validate_path

    [ "$status" -eq 0 ]
    [[ "$output" == *'"kind": "symbol"'* ]]
    [[ "$output" == *'"name": "validate_path"'* ]]
    [[ "$output" == *'"file": "scripts/lib/common.sh"'* ]]
    [[ "$output" == *'"file": "scripts/tool.sh"'* ]]
}
