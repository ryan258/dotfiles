#!/usr/bin/env bats

# test_ai_staff_boundary.sh - AI Staff HQ boundary and override coverage.
#
# This file covers the AI_STAFF_DIR override path (sibling checkout) and the
# missing-AI_STAFF_DIR degradation path for dhp-swarm.py.
# The daily-loop missing-AI_STAFF_DIR case is covered separately by
# tests/test_optional_product_degradation.sh ("dhp dispatcher reports missing
# AI Staff HQ without a stack trace").

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    setup_test_environment
    export DOTFILES_DIR="$TEST_DIR/dotfiles"
    export STAFF_DIR="$TEST_DIR/external-ai-staff-hq"

    mkdir -p "$DOTFILES_DIR/bin" "$STAFF_DIR/orchestrator" "$STAFF_DIR/workflows/schemas"
    cp "$BATS_TEST_DIRNAME/../bin/dhp-swarm.py" "$DOTFILES_DIR/bin/dhp-swarm.py"

    touch "$STAFF_DIR/orchestrator/__init__.py"
    touch "$STAFF_DIR/workflows/__init__.py"
    touch "$STAFF_DIR/workflows/schemas/__init__.py"

    cat > "$STAFF_DIR/orchestrator/swarm_runner.py" <<'PY'
class SwarmRunner:
    def __init__(self, staff_dir, **kwargs):
        self.staff_dir = staff_dir

    def run_swarm(self, brief, use_squad=None):
        return {"final_output": f"staff_dir={self.staff_dir}; brief={brief.strip()}"}
PY

    cat > "$STAFF_DIR/workflows/schemas/swarm.py" <<'PY'
class SwarmConfig:
    def __init__(self, **kwargs):
        self.kwargs = kwargs
PY
}

teardown() {
    teardown_test_environment
}

@test "dhp-swarm imports AI Staff HQ from AI_STAFF_DIR" {
    run bash -c "printf 'external brief' | AI_STAFF_DIR='$STAFF_DIR' python3 '$DOTFILES_DIR/bin/dhp-swarm.py'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"staff_dir=$STAFF_DIR/staff"* ]]
    [[ "$output" == *"brief=external brief"* ]]
}
