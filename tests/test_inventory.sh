#!/usr/bin/env bats

# test_inventory.sh - Coverage for Phase 0 inventory generation.

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    export DOTFILES_DIR
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
}

teardown() {
    teardown_test_environment
}

@test "inventory.sh summary reports core baseline categories" {
    run "$DOTFILES_DIR/scripts/inventory.sh" summary

    [ "$status" -eq 0 ]
    [[ "$output" == *"Dotfiles Inventory Summary"* ]]
    [[ "$output" == *"dhp wrapper files"* ]]
    [[ "$output" == *"aliases"* ]]
    [[ "$output" == *"coach core LOC"* ]]
}

@test "inventory.sh generate writes Phase 0 generated docs" {
    local out_dir="$TEST_DIR/generated"

    run "$DOTFILES_DIR/scripts/inventory.sh" generate "$out_dir"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Generated inventory docs"* ]]

    assert_file_exists "$out_dir/baseline-metrics.md"
    assert_file_exists "$out_dir/script-inventory.md"
    assert_file_exists "$out_dir/alias-inventory.md"
    assert_file_exists "$out_dir/test-coverage-map.md"
    assert_file_exists "$out_dir/external-dependencies.md"

    assert_file_contains "$out_dir/baseline-metrics.md" "Frozen Phase 0 Baseline"
    assert_file_contains "$out_dir/script-inventory.md" "Dispatcher Wrappers"
    assert_file_contains "$out_dir/script-inventory.md" "Bin Entrypoints"
    assert_file_contains "$out_dir/alias-inventory.md" "Alias Inventory"
    assert_file_contains "$out_dir/test-coverage-map.md" "Daily Loop Coverage"
    assert_file_contains "$out_dir/external-dependencies.md" "External Dependencies"
}

@test "inventory.sh generate does not overwrite frozen baseline" {
    local out_dir="$TEST_DIR/generated"
    mkdir -p "$out_dir"
    cat > "$out_dir/baseline-metrics.md" <<'EOF'
# Frozen Phase 0 Baseline

SENTINEL_BASELINE_VALUE
EOF

    run "$DOTFILES_DIR/scripts/inventory.sh" generate "$out_dir"

    [ "$status" -eq 0 ]
    [[ "$output" == *"baseline-metrics.md is frozen"* ]]
    assert_file_contains "$out_dir/baseline-metrics.md" "SENTINEL_BASELINE_VALUE"
    assert_file_exists "$out_dir/script-inventory.md"
}

@test "inventory.sh generate overwrites frozen baseline with INVENTORY_FORCE_FREEZE" {
    local out_dir="$TEST_DIR/generated"
    mkdir -p "$out_dir"
    cat > "$out_dir/baseline-metrics.md" <<'EOF'
# Frozen Phase 0 Baseline

SENTINEL_BASELINE_VALUE
EOF

    run env INVENTORY_FORCE_FREEZE=1 "$DOTFILES_DIR/scripts/inventory.sh" generate "$out_dir"

    [ "$status" -eq 0 ]

    run grep -q "SENTINEL_BASELINE_VALUE" "$out_dir/baseline-metrics.md"
    [ "$status" -ne 0 ]
    assert_file_contains "$out_dir/baseline-metrics.md" "Numeric Exit Gates"
}

@test "inventory.sh alias class counts sum to total aliases" {
    local out_dir="$TEST_DIR/generated"

    run "$DOTFILES_DIR/scripts/inventory.sh" generate "$out_dir"

    [ "$status" -eq 0 ]

    local total daily compat convenience risky sum
    total=$(awk -F': ' '/^- Aliases:/ {print $2}' "$out_dir/alias-inventory.md")
    daily=$(awk -F': ' '/^- Daily-core aliases:/ {print $2}' "$out_dir/alias-inventory.md")
    compat=$(awk -F': ' '/^- Compatibility aliases:/ {print $2}' "$out_dir/alias-inventory.md")
    convenience=$(awk -F': ' '/^- Convenience aliases:/ {print $2}' "$out_dir/alias-inventory.md")
    risky=$(awk -F': ' '/^- Risky\/surprising aliases:/ {print $2}' "$out_dir/alias-inventory.md")
    sum=$((daily + compat + convenience + risky))

    [ "$sum" -eq "$total" ]
}
