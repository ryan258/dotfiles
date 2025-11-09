#!/bin/bash
set -e

# dhp-stoic.sh - Stoic Coach dispatcher
# Mindset coaching, reflections, journaling prompts

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

STAFF_FILE="$AI_STAFF_DIR/staff/health-lifestyle/stoic-coach.yaml"
if [ ! -f "$STAFF_FILE" ]; then
    echo "Error: Stoic Coach specialist not found at $STAFF_FILE" >&2; exit 1
fi

PIPED_CONTENT=$(cat -)
if [ -z "$PIPED_CONTENT" ]; then
    echo "Usage: <input> | $0" >&2; exit 1
fi

echo "Activating 'Stoic Coach' via OpenRouter (Model: $MODEL)..." >&2
echo "---" >&2

MASTER_PROMPT=$(cat "$STAFF_FILE")
MASTER_PROMPT+="

--- STOIC COACHING REQUEST ---
$PIPED_CONTENT

Provide stoic-inspired guidance with:
1. Reframe the situation through stoic principles
2. What is within your control vs. outside it
3. A practical action or reflection
4. A relevant stoic quote or teaching

Keep it grounded, practical, and encouraging.
"

JSON_PAYLOAD=$(jq -n --arg model "$MODEL" --arg prompt "$MASTER_PROMPT" \
    '{model: $model, messages: [{role: "user", content: $prompt}]}')

curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" | jq -r '.choices[0].message.content'

echo -e "\n---" >&2
echo "SUCCESS: 'Stoic Coach' guidance complete." >&2
