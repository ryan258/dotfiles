#!/bin/bash
set -e

# dhp-brand.sh - Brand Builder dispatcher
# Brand positioning, voice/tone, competitive analysis

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

STAFF_FILE="$AI_STAFF_DIR/staff/strategy/brand-builder.yaml"
if [ ! -f "$STAFF_FILE" ]; then
    echo "Error: Brand Builder specialist not found at $STAFF_FILE" >&2; exit 1
fi

PIPED_CONTENT=$(cat -)
if [ -z "$PIPED_CONTENT" ]; then
    echo "Usage: <input> | $0" >&2; exit 1
fi

echo "Activating 'Brand Builder' via OpenRouter (Model: $MODEL)..." >&2
echo "---" >&2

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

JSON_PAYLOAD=$(jq -n --arg model "$MODEL" --arg prompt "$MASTER_PROMPT" \
    '{model: $model, messages: [{role: "user", content: $prompt}]}')

curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" | jq -r '.choices[0].message.content'

echo -e "\n---" >&2
echo "SUCCESS: 'Brand Builder' analysis complete." >&2
