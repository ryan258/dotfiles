#!/bin/bash
set -e

# dhp-market.sh - Market Analyst dispatcher
# SEO research, trend analysis, audience insights

DOTFILES_DIR="$HOME/dotfiles"
AI_STAFF_DIR="$DOTFILES_DIR/ai-staff-hq"

if [ -f "$DOTFILES_DIR/.env" ]; then source "$DOTFILES_DIR/.env"; fi

if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    echo "Error: curl and jq are required." >&2; exit 1
fi

if [ -z "$OPENROUTER_API_KEY" ]; then
    echo "Error: OPENROUTER_API_KEY not set." >&2; exit 1
fi

MODEL="${DHP_STRATEGY_MODEL:-${DHP_CONTENT_MODEL}}"
if [ -z "$MODEL" ]; then
    echo "Error: No model configured." >&2; exit 1
fi

STAFF_FILE="$AI_STAFF_DIR/staff/strategy/market-analyst.yaml"
if [ ! -f "$STAFF_FILE" ]; then
    echo "Error: Market Analyst specialist not found at $STAFF_FILE" >&2; exit 1
fi

PIPED_CONTENT=$(cat -)
if [ -z "$PIPED_CONTENT" ]; then
    echo "Usage: <input> | $0" >&2; exit 1
fi

echo "Activating 'Market Analyst' via OpenRouter (Model: $MODEL)..." >&2
echo "---" >&2

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

JSON_PAYLOAD=$(jq -n --arg model "$MODEL" --arg prompt "$MASTER_PROMPT" \
    '{model: $model, messages: [{role: "user", content: $prompt}]}')

curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" | jq -r '.choices[0].message.content'

echo -e "\n---" >&2
echo "SUCCESS: 'Market Analyst' analysis complete." >&2
