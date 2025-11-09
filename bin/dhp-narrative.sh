#!/bin/bash
set -e

# dhp-narrative.sh - Narrative Designer dispatcher
# Story structure, plot development, character arcs

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

STAFF_FILE="$AI_STAFF_DIR/staff/producers/narrative-designer.yaml"
if [ ! -f "$STAFF_FILE" ]; then
    echo "Error: Narrative Designer specialist not found at $STAFF_FILE" >&2; exit 1
fi

PIPED_CONTENT=$(cat -)
if [ -z "$PIPED_CONTENT" ]; then
    echo "Usage: <input> | $0" >&2; exit 1
fi

echo "Activating 'Narrative Designer' via OpenRouter (Model: $MODEL)..." >&2
echo "---" >&2

MASTER_PROMPT=$(cat "$STAFF_FILE")
MASTER_PROMPT+="

--- NARRATIVE DESIGN REQUEST ---
$PIPED_CONTENT

Provide narrative design with:
1. Story structure analysis (3-act, Hero's Journey, etc.)
2. Plot development suggestions
3. Character arc recommendations
4. Key dramatic moments and beats
"

JSON_PAYLOAD=$(jq -n --arg model "$MODEL" --arg prompt "$MASTER_PROMPT" \
    '{model: $model, messages: [{role: "user", content: $prompt}]}')

curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" | jq -r '.choices[0].message.content'

echo -e "\n---" >&2
echo "SUCCESS: 'Narrative Designer' analysis complete." >&2
