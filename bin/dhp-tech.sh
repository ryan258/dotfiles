#!/bin/bash
set -e

# dhp-tech.sh - Technical Analyst dispatcher (Swarm Edition)
# Code analysis, bug fixing, automation engineering

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

# --- 1. SETUP ---
dhp_setup_env

# --- 2. FLAG PARSING ---
dhp_parse_flags "$@"
set -- "$@"

# --- 3. VALIDATION & INPUT ---
validate_dependencies curl jq
ensure_api_key OPENROUTER_API_KEY

dhp_get_input "$@"

if [ -z "$PIPED_CONTENT" ]; then
    echo "Usage:" >&2
    echo "  cat <script> | $0 [options]" >&2
    echo "  $0 [options] \"Describe bug\"" >&2
    exit 1
fi

# --- 4. MODEL & STAFF ---
MODEL="${TECH_MODEL:-${DHP_TECH_MODEL:-deepseek/deepseek-r1-0528:free}}"
OUTPUT_DIR=$(default_output_dir "$HOME/Documents/AI_Staff_HQ_Outputs/Technical/Code_Analysis" "DHP_TECH_OUTPUT_DIR")
mkdir -p "$OUTPUT_DIR"
SLUG=$(echo "$PIPED_CONTENT" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | cut -c 1-50)
OUTPUT_FILE="$OUTPUT_DIR/${SLUG}.md"

echo "Activating 'AI-Staff-HQ' Swarm for Technical Analysis..." >&2
echo "Model: $MODEL"
echo "Saving to: $OUTPUT_FILE" >&2
echo "---" >&2

# --- 5. BUILD ENHANCED BRIEF ---
ENHANCED_BRIEF="Analyze the following code/request:

\`\`\`
$PIPED_CONTENT
\`\`\`

--- TECHNICAL OBJECTIVES ---
1. Analyze the provided code or request for bugs, errors, or optimization opportunities.
2. Identify the root cause of any issues.
3. Provide the corrected code or solution.
4. Explain the fix and any best practices applied.

DELIVERABLE: A technical report including Bug Analysis, The Fix, and Corrected Code block."

# --- 6. EXECUTE SWARM ORCHESTRATION ---
PYTHON_CMD="uv run --project \"$AI_STAFF_DIR\" python \"$DOTFILES_DIR/bin/dhp-swarm.py\""

if [ -n "$MODEL" ]; then
    PYTHON_CMD="$PYTHON_CMD --model \"$MODEL\""
fi

if [ -n "$PARAM_TEMPERATURE" ]; then
    PYTHON_CMD="$PYTHON_CMD --temperature $PARAM_TEMPERATURE"
else
    # Technical work usually benefits from lower temperature
    PYTHON_CMD="$PYTHON_CMD --temperature 0.2"
fi

PYTHON_CMD="$PYTHON_CMD --parallel --max-parallel 5"
PYTHON_CMD="$PYTHON_CMD --auto-approve"

echo "Executing technical swarm..." >&2
echo "$ENHANCED_BRIEF" | eval "$PYTHON_CMD" | tee "$OUTPUT_FILE"

if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    echo -e "\n---" >&2
    echo "✓ SUCCESS: Technical analysis completed" >&2
else
    echo "✗ FAILED: Swarm orchestration encountered an error" >&2
    exit 1
fi
