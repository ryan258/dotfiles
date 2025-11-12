#!/bin/bash
set -e

# dhp-market.sh - Market Analyst dispatcher
# SEO research, trend analysis, audience insights

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
    echo "Usage:" >&2
    echo "  echo \"prompt\" | $0 [options]" >&2
    echo "  $0 [options] \"prompt\"" >&2
    echo "Options:" >&2
    echo "  --stream    Enable real-time streaming output" >&2
    exit 1
fi

# --- 4. MODEL & STAFF ---
MODEL="${MARKET_MODEL:-${DHP_STRATEGY_MODEL:-meta-llama/llama-4-scout:free}}"
STAFF_FILE="$AI_STAFF_DIR/staff/strategy/market-analyst.yaml"
if [ ! -f "$STAFF_FILE" ]; then
    echo "Error: Market Analyst specialist not found at $STAFF_FILE" >&2; exit 1
fi

# --- 5. OUTPUT SETUP ---
OUTPUT_DIR=$(default_output_dir "$HOME/Documents/AI_Staff_HQ_Outputs/Strategy/Market_Research" "DHP_MARKET_OUTPUT_DIR")
mkdir -p "$OUTPUT_DIR"
SLUG=$(echo "$PIPED_CONTENT" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | cut -c 1-50)
OUTPUT_FILE="$OUTPUT_DIR/${SLUG}.md"

echo "Activating 'Market Analyst' via OpenRouter (Model: $MODEL)..." >&2
echo "Saving to: $OUTPUT_FILE" >&2
echo "---" >&2

# --- 6. PROMPT ASSEMBLY ---
MASTER_PROMPT=$(cat "$STAFF_FILE")
MASTER_PROMPT+="

--- MARKET ANALYSIS REQUEST ---
$PIPED_CONTENT

Provide market analysis with:
1. Keyword opportunities and SEO potential
2. Current market trends and gaps
3. Target audience insights
4. Competitive landscape overview
"

# --- 7. EXECUTION ---
if [ "$USE_STREAMING" = true ]; then
    call_openrouter "$MODEL" "$MASTER_PROMPT" "--stream" "dhp-market" | tee "$OUTPUT_FILE"
else
    call_openrouter "$MODEL" "$MASTER_PROMPT" "" "dhp-market" | tee "$OUTPUT_FILE"
fi

# Check if API call succeeded
if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    echo -e "\n---" >&2
    echo "SUCCESS: 'Market Analyst' analysis complete." >&2
else
    echo "FAILED: 'Market Analyst' encountered an error." >&2
    exit 1
fi
