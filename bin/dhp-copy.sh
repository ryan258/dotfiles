#!/bin/bash
set -e

# dhp-copy.sh - Copywriter dispatcher
# Sales copy, email sequences, landing pages

DOTFILES_DIR="$HOME/dotfiles"
AI_STAFF_DIR="$DOTFILES_DIR/ai-staff-hq"

if [ -f "$DOTFILES_DIR/.env" ]; then source "$DOTFILES_DIR/.env"; fi

if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    echo "Error: curl and jq are required." >&2; exit 1
fi

if [ -z "$OPENROUTER_API_KEY" ]; then
    echo "Error: OPENROUTER_API_KEY not set." >&2; exit 1
fi

MODEL="${DHP_CREATIVE_MODEL}"
if [ -z "$MODEL" ]; then
    echo "Error: DHP_CREATIVE_MODEL not set." >&2; exit 1
fi

STAFF_FILE="$AI_STAFF_DIR/staff/producers/copywriter.yaml"
if [ ! -f "$STAFF_FILE" ]; then
    echo "Error: Copywriter specialist not found at $STAFF_FILE" >&2; exit 1
fi

PIPED_CONTENT=$(cat -)
if [ -z "$PIPED_CONTENT" ]; then
    echo "Usage: <input> | $0" >&2; exit 1
fi

echo "Activating 'Copywriter' via OpenRouter (Model: $MODEL)..." >&2
echo "---" >&2

MASTER_PROMPT=$(cat "$STAFF_FILE")
MASTER_PROMPT+="

--- COPYWRITING REQUEST ---
$PIPED_CONTENT

Provide compelling copy with:
1. Attention-grabbing headlines
2. Benefit-driven body copy
3. Clear call-to-action
4. Persuasive messaging that converts
"

JSON_PAYLOAD=$(jq -n --arg model "$MODEL" --arg prompt "$MASTER_PROMPT" \
    '{model: $model, messages: [{role: "user", content: $prompt}]}')

curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" | jq -r '.choices[0].message.content'

echo -e "\n---" >&2
echo "SUCCESS: 'Copywriter' copy complete." >&2
