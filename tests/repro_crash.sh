#!/bin/bash
set -euo pipefail

# Create temp home
TEST_HOME=$(mktemp -d)
export HOME="$TEST_HOME"
mkdir -p "$HOME/.config/dotfiles-data"

# Create meds file with only DOSE line (no MED lines)
echo "DOSE|2025-11-21 10:00|TestMed" > "$HOME/.config/dotfiles-data/medications.txt"

# Run ai_suggest.sh
# We need to find the script. Assuming we run from dotfiles root.
SCRIPT_DIR="$(pwd)/scripts"
export PATH="$SCRIPT_DIR:$PATH"

echo "Running ai_suggest.sh..."
if bash "$SCRIPT_DIR/ai_suggest.sh"; then
    echo "✅ Success: ai_suggest.sh did not crash"
    rm -rf "$TEST_HOME"
    exit 0
else
    echo "❌ Failure: ai_suggest.sh crashed"
    rm -rf "$TEST_HOME"
    exit 1
fi
