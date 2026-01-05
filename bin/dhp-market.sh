#!/bin/bash
set -e

# dhp-market.sh - Market Analyst dispatcher (Swarm Edition)
# SEO research, trend analysis, audience insights

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
    echo "  echo \"prompt\" | $0 [options]" >&2
    echo "  $0 [options] \"prompt\"" >&2
    echo "Options:" >&2
    echo "  --stream    Enable real-time streaming output" >&2
    exit 1
fi

# --- 4. MODEL & STAFF ---
MODEL="${MARKET_MODEL:-${DHP_STRATEGY_MODEL:-meta-llama/llama-4-scout:free}}"
OUTPUT_DIR=$(default_output_dir "$HOME/Documents/AI_Staff_HQ_Outputs/Strategy/Market_Research" "DHP_MARKET_OUTPUT_DIR")
mkdir -p "$OUTPUT_DIR"
SLUG=$(echo "$PIPED_CONTENT" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | cut -c 1-50)
OUTPUT_FILE="$OUTPUT_DIR/${SLUG}.md"

echo "Activating 'AI-Staff-HQ' Swarm for Market Analysis..." >&2
echo "Brief: $PIPED_CONTENT"
echo "Model: $MODEL"
echo "Saving to: $OUTPUT_FILE" >&2
echo "---" >&2

# --- 5. BUILD ENHANCED BRIEF ---
# We inject specific market analysis requirements into the brief
ENHANCED_BRIEF="$PIPED_CONTENT

--- MARKET ANALYSIS OBJECTIVES ---
Conduct a comprehensive market analysis covering:
1. Keyword opportunities and SEO potential (high volume, low competition)
2. Current market trends, emerging patterns, and unmet needs
3. Target audience insights (demographics, psychographics, pain points)
4. Competitive landscape overview (major players, gaps, positioning)

DELIVERABLE: A detailed market analysis report with actionable strategic recommendations."

# --- 6. EXECUTE SWARM ORCHESTRATION ---
PYTHON_CMD="uv run --project \"$AI_STAFF_DIR\" python \"$DOTFILES_DIR/bin/dhp-swarm.py\""

if [ -n "$MODEL" ]; then
    PYTHON_CMD="$PYTHON_CMD --model \"$MODEL\""
fi

# Market analysis benefits from precision, so we might want lower temperature? 
# But swarm defaults are usually fine. Let's keep defaults or use params.
if [ -n "$PARAM_TEMPERATURE" ]; then
    PYTHON_CMD="$PYTHON_CMD --temperature $PARAM_TEMPERATURE"
fi

# Enable parallel execution
PYTHON_CMD="$PYTHON_CMD --parallel --max-parallel 5"
PYTHON_CMD="$PYTHON_CMD --auto-approve"

# Execute
echo "Executing market analysis swarm..." >&2
echo "$ENHANCED_BRIEF" | eval "$PYTHON_CMD" | tee "$OUTPUT_FILE"

if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    echo -e "\n---" >&2
    echo "✓ SUCCESS: Market analysis generated via swarm" >&2
else
    echo "✗ FAILED: Swarm orchestration encountered an error" >&2
    exit 1
fi
