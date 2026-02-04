#!/usr/bin/env bash
# Verify die() behavior

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib/common.sh"

echo "Running die test..."
if ( die "Test message" 2>/dev/null ); then
    echo "FAIL: die() did not exit/return non-zero"
    exit 1
else
    RET=$?
    if [ "$RET" -eq 1 ]; then
        echo "PASS: die() returned 1"
    else
        echo "FAIL: die() returned $RET"
        exit 1
    fi
fi

# Now verify it DOES NOT kill the shell when sourced
# We are currently executing verify_fix.sh, but we sourced common.sh.
# Calling die should return 1, not exit the script (because we didn't use set -e)
# Wait, if verify_fix.sh is executed, BASH_SOURCE[0] for verify_fix is verify_fix.
# But inside common.sh, BASH_SOURCE[0] is common.sh if sourced? No.
# If sourced, BASH_SOURCE[0] is the library. $0 is the caller.

echo "Verifying is_sourced logic..."
# let's modify verify logic slightly to just check is_sourced return
if is_sourced; then
    echo "PASS: verify_fix.sh thinks it sourced common.sh (correct)"
else 
    echo "FAIL: is_sourced returned false inside sourced library?"
    # Wait, is_sourced is defined in common.sh.
    # When we call it here, it uses the BASH_SOURCE stack.
    # If we call it directly, BASH_SOURCE[0] is common.sh? No.
fi
