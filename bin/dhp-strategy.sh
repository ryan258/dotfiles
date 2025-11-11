#!/bin/bash
set -e # Exit immediately if a command fails

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

# --- 1. SETUP ---
dhp_setup_env

# --- 2. FLAG PARSING ---
dhp_parse_flags "$@"
# After dhp_parse_flags, the remaining arguments are in "$@"
set -- "$@"

# --- 3. VALIDATION & INPUT ---
validate_dependencies curl jq
ensure_api_key OPENROUTER_API_KEY

dhp_get_input "$@"

if [ -z "$PIPED_CONTENT" ]; then
    echo "Usage: <input> | $0 [--stream]" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --stream    Enable real-time streaming output" >&2
    echo "" >&2
    echo "Error: No input provided via stdin." >&2
    exit 1
fi

# --- 4. MODEL & STAFF ---
MODEL="${STRATEGY_MODEL:-${DHP_STRATEGY_MODEL:-openrouter/polaris-alpha}}"
STAFF_FILE="$AI_STAFF_DIR/staff/strategy/chief-of-staff.yaml"
if [ ! -f "$STAFF_FILE" ]; then
    echo "Error: Chief of Staff specialist not found at $STAFF_FILE" >&2
    exit 1
fi

# --- 5. OUTPUT SETUP ---
OUTPUT_DIR=$(default_output_dir "$HOME/Documents/AI_Staff_HQ_Outputs/Strategy/Analysis" "DHP_STRATEGY_OUTPUT_DIR")
mkdir -p "$OUTPUT_DIR"
SLUG=$(echo "$PIPED_CONTENT" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | cut -c 1-50)
OUTPUT_FILE="$OUTPUT_DIR/${SLUG}.md"

echo "Activating 'Chief of Staff' via OpenRouter (Model: $MODEL)..." >&2
echo "Saving to: $OUTPUT_FILE" >&2
echo "---" >&2

# --- 6. BUILD MASTER PROMPT ---
MASTER_PROMPT_FILE=$(mktemp)
trap 'rm -f "$MASTER_PROMPT_FILE"' EXIT

# Load Chief of Staff persona
cat "$STAFF_FILE" > "$MASTER_PROMPT_FILE"

# Add the analysis request
echo -e "\n\n--- ANALYSIS REQUEST ---

You are the Chief of Staff from AI-Staff-HQ. Analyze the following information and provide strategic insights, patterns, and actionable recommendations.

**INPUT:**
---
$PIPED_CONTENT
---

**DELIVERABLE:**
Provide a clear, actionable analysis with:
1. **Key Insights:** Main patterns and observations
2. **Strategic Recommendations:** Specific next actions
3. **Potential Risks/Opportunities:** What to watch for

Keep your response concise and actionable.
" >> "$MASTER_PROMPT_FILE"

# --- 7. EXECUTE API CALL ---
PROMPT_CONTENT=$(cat "$MASTER_PROMPT_FILE")

if [ "$USE_STREAMING" = true ]; then
    call_openrouter "$MODEL" "$PROMPT_CONTENT" --stream | tee "$OUTPUT_FILE"
else
    call_openrouter "$MODEL" "$PROMPT_CONTENT" | tee "$OUTPUT_FILE"
fi

# Check if API call succeeded
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo -e "\n---" >&2
    echo "SUCCESS: 'Chief of Staff' analysis complete." >&2
else
    echo "FAILED: 'Chief of Staff' encountered an error." >&2
    exit 1
fi
