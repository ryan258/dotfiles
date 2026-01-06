#!/bin/bash
set -e # Exit immediately if a command fails

# dhp-strategy.sh - Strategic Analysis dispatcher (Swarm Edition)
# High-level analysis, synthesis, and decision support

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

# --- 1. SETUP ---
dhp_setup_env

# --- 2. FLAG PARSING ---
dhp_parse_flags "$@"
set -- "${REMAINING_ARGS[@]}"

# --- 3. VALIDATION & INPUT ---
validate_dependencies curl jq
ensure_api_key OPENROUTER_API_KEY

dhp_get_input "$@"

if [ -z "$PIPED_CONTENT" ]; then
    echo "Usage: <input> | $0 [--stream]" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --verbose   Show detailed progress (wave counts, specialist names, timings)" >&2
    echo "  --stream    Stream task outputs as JSON events" >&2
    echo "" >&2
    echo "Error: No input provided via stdin." >&2
    exit 1
fi

# --- 4. MODEL & STAFF ---
MODEL="${STRATEGY_MODEL:-${DHP_STRATEGY_MODEL:-openrouter/polaris-alpha}}"
OUTPUT_DIR=$(default_output_dir "$HOME/Documents/AI_Staff_HQ_Outputs/Strategy/Analysis" "DHP_STRATEGY_OUTPUT_DIR")
mkdir -p "$OUTPUT_DIR"
SLUG=$(echo "$PIPED_CONTENT" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | cut -c 1-50)
OUTPUT_FILE="$OUTPUT_DIR/${SLUG}.md"

echo "Activating 'AI-Staff-HQ' Swarm for Strategic Analysis..." >&2
echo "Model: $MODEL"
echo "Saving to: $OUTPUT_FILE" >&2
echo "---" >&2

# --- 5. BUILD ENHANCED BRIEF ---
ENHANCED_BRIEF="Analyze the following inputs and provide strategic direction:

\`\`\`
$PIPED_CONTENT
\`\`\`

--- STRATEGIC ANALYSIS OBJECTIVES ---
1. **Key Insights:** Synthesize main patterns, observations, and hidden dynamics.
2. **Strategic Recommendations:** Provide specific, high-leverage next actions.
3. **Risk/Opportunity Assessment:** Identify potential pitfalls and upside vectors.
4. **Execution Framework:** High-level roadmap or immediate next steps.

DELIVERABLE: A high-level strategic analysis and decision support document."

# --- 6. EXECUTE SWARM ORCHESTRATION ---
PYTHON_CMD="uv run --project \"$AI_STAFF_DIR\" python \"$DOTFILES_DIR/bin/dhp-swarm.py\""

if [ -n "$MODEL" ]; then
    PYTHON_CMD="$PYTHON_CMD --model \"$MODEL\""
fi

if [ -n "$PARAM_TEMPERATURE" ]; then
    PYTHON_CMD="$PYTHON_CMD --temperature $PARAM_TEMPERATURE"
else
    # Balance insight with grounding
    PYTHON_CMD="$PYTHON_CMD --temperature 0.6"
fi

PYTHON_CMD="$PYTHON_CMD --parallel --max-parallel 5"
PYTHON_CMD="$PYTHON_CMD --auto-approve"

if [ "$USE_VERBOSE" = "true" ]; then
    PYTHON_CMD="$PYTHON_CMD --verbose"
fi

if [ "$USE_STREAMING" = "true" ]; then
    PYTHON_CMD="$PYTHON_CMD --stream"
fi

echo "Executing strategy swarm..." >&2
echo "$ENHANCED_BRIEF" | eval "$PYTHON_CMD" | tee "$OUTPUT_FILE"

if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    echo -e "\n---" >&2
    echo "✓ SUCCESS: Strategic analysis completed via swarm" >&2
else
    echo "✗ FAILED: Swarm orchestration encountered an error" >&2
    exit 1
fi
