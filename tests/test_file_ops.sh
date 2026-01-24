#!/usr/bin/env bash
# Test atomic file operations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/scripts/lib/file_ops.sh"

TEST_FILE="test_atomic_ops.txt"

# Cleanup
cleanup() {
    rm -f "$TEST_FILE"
}
trap cleanup EXIT

echo "Testing atomic_write..."
atomic_write "Line 1" "$TEST_FILE"
if [[ "$(cat "$TEST_FILE")" == "Line 1" ]]; then
    echo "PASS: atomic_write"
else
    echo "FAIL: atomic_write"
    exit 1
fi

echo "Testing atomic_prepend..."
atomic_prepend "Line 0" "$TEST_FILE"
if [[ "$(head -n 1 "$TEST_FILE")" == "Line 0" ]]; then
    echo "PASS: atomic_prepend"
else
    echo "FAIL: atomic_prepend"
    exit 1
fi

echo "Testing atomic_replace_line..."
atomic_replace_line 1 "Line Zero" "$TEST_FILE"
if [[ "$(head -n 1 "$TEST_FILE")" == "Line Zero" ]]; then
    echo "PASS: atomic_replace_line"
else
    echo "FAIL: atomic_replace_line"
    exit 1
fi

echo "Testing atomic_delete_line..."
atomic_delete_line 1 "$TEST_FILE"
if [[ "$(head -n 1 "$TEST_FILE")" == "Line 1" ]]; then
    echo "PASS: atomic_delete_line"
else
    echo "FAIL: atomic_delete_line"
    exit 1
fi

echo "All tests passed!"
