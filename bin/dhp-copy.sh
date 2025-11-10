#!/bin/bash
set -e

# dhp-copy.sh - Copywriter dispatcher
# Sales copy, email sequences, landing pages

DOTFILES_DIR="$HOME/dotfiles"
AI_STAFF_DIR="$DOTFILES_DIR/ai-staff-hq"

if [ -f "$DOTFILES_DIR/.env" ]; then source "$DOTFILES_DIR/.env"; fi
# Source shared library
if [ -f "$DOTFILES_DIR/bin/dhp-lib.sh" ]; then
    source "$DOTFILES_DIR/bin/dhp-lib.sh"
else
    echo "Error: Shared library dhp-lib.sh not found" >&2
    exit 1
fi

if [ -f "$DOTFILES_DIR/bin/dhp-utils.sh" ]; then
    source "$DOTFILES_DIR/bin/dhp-utils.sh"
fi

# Parse flags
USE_STREAMING=false
while [[ "$1" == --* ]]; do
    case "$1" in
        --stream)
            USE_STREAMING=true
            shift
            ;;
        *)
            echo "Unknown flag: $1" >&2
            exit 1
            ;;
    esac
done


validate_dependencies curl jq
ensure_api_key OPENROUTER_API_KEY

# Load model from .env, fallback to legacy variable, then default
MODEL="${CREATIVE_MODEL:-${DHP_CREATIVE_MODEL:-meta-llama/llama-4-maverick:free}}"

STAFF_FILE="$AI_STAFF_DIR/staff/producers/copywriter.yaml"
if [ ! -f "$STAFF_FILE" ]; then
    echo "Error: Copywriter specialist not found at $STAFF_FILE" >&2; exit 1
fi

TEMP_INPUT="$*"
if [ -n "$TEMP_INPUT" ]; then
  PIPED_CONTENT="$TEMP_INPUT"
else
  PIPED_CONTENT=$(cat)
fi
if [ -z "$PIPED_CONTENT" ]; then
    echo "Usage:" >&2
    echo "  echo \"prompt\" | $0 [options]" >&2
    echo "  $0 [options] \"prompt\"" >&2
    echo "Options:" >&2
    echo "  --stream    Enable real-time streaming output" >&2
    exit 1
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

# Execute the API call with error handling and optional streaming
if [ "$USE_STREAMING" = true ]; then
    call_openrouter "$MODEL" "$MASTER_PROMPT" --stream
else
    call_openrouter "$MODEL" "$MASTER_PROMPT"
fi

# Check if API call succeeded
if [ $? -eq 0 ]; then
    echo -e "\n---" >&2
    echo "SUCCESS: 'Copywriter' copy complete." >&2
else
    echo "FAILED: 'Copywriter' encountered an error." >&2
    exit 1
fi
