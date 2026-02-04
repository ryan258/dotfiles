#!/usr/bin/env bash

# tests/helpers/mock_ai.sh
# Mock AI dispatcher for BATS tests

# Usage: mock_ai_response "The response text you want"
# This requires the test to export a simpler mock function for the actual tool being called
mock_ai_response() {
    local script_name="${2:-dhp-strategy}"

    if [ -z "$TEST_DIR" ]; then
        echo "Error: TEST_DIR not set" >&2
        return 1
    fi

    export MOCK_AI_RESPONSE="$1"
    
    # We create a temporary script that acts as the AI dispatcher
    cat <<'EOF' > "$TEST_DIR/$script_name"
#!/usr/bin/env bash
printf '%s\n' "$MOCK_AI_RESPONSE"
EOF
    chmod +x "$TEST_DIR/$script_name"
    
    # Add TEST_DIR to PATH so our mock is found first
    export PATH="$TEST_DIR:$PATH"
}
