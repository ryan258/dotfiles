#!/bin/bash
set -e

# dhp-brand.sh - Brand Builder dispatcher
# Brand positioning, voice/tone, competitive analysis

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
MODEL="${STRATEGY_MODEL:-${DHP_STRATEGY_MODEL:-openrouter/polaris-alpha}}"
STAFF_FILE="$AI_STAFF_DIR/staff/strategy/brand-builder.yaml"
if [ ! -f "$STAFF_FILE" ]; then
    echo "Error: Brand Builder specialist not found at $STAFF_FILE" >&2; exit 1
fi

echo "Activating 'Brand Builder' via OpenRouter (Model: $MODEL)..." >&2
echo "---" >&2

# --- 5. PROMPT ASSEMBLY ---
MASTER_PROMPT=$(cat "$STAFF_FILE")
MASTER_PROMPT+="

--- BRAND ANALYSIS REQUEST ---
$PIPED_CONTENT

Provide brand positioning analysis with:
1. Core brand attributes and values
2. Voice and tone recommendations
3. Competitive differentiation opportunities
4. Key messaging pillars
"

# --- 6. EXECUTION ---
if [ "$USE_STREAMING" = true ]; then
    call_openrouter "$MODEL" "$MASTER_PROMPT" --stream
else
    call_openrouter "$MODEL" "$MASTER_PROMPT"
fi

# Check if API call succeeded
if [ $? -eq 0 ]; then
    echo -e "\n---" >&2
    echo "SUCCESS: 'Brand Builder' analysis complete." >&2
else
    echo "FAILED: 'Brand Builder' encountered an error." >&2
    exit 1
fi
