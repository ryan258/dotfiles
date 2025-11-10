#!/bin/bash
set -e

# dhp-narrative.sh - Narrative Designer dispatcher
# Story structure, plot development, character arcs

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


if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    echo "Error: curl and jq are required." >&2; exit 1
fi

if [ -z "$OPENROUTER_API_KEY" ]; then
    echo "Error: OPENROUTER_API_KEY not set." >&2; exit 1
fi

# Load model from .env, fallback to legacy variable, then default
MODEL="${CREATIVE_MODEL:-${DHP_CREATIVE_MODEL:-meta-llama/llama-4-maverick:free}}"

STAFF_FILE="$AI_STAFF_DIR/staff/producers/narrative-designer.yaml"
if [ ! -f "$STAFF_FILE" ]; then
    echo "Error: Narrative Designer specialist not found at $STAFF_FILE" >&2; exit 1
fi

PIPED_CONTENT=$(cat -)
if [ -z "$PIPED_CONTENT" ]; then
    echo "Usage: <input> | $0 [--stream]" >&2
    echo "Options:" >&2
    echo "  --stream    Enable real-time streaming output" >&2
    exit 1
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

# Execute the API call with error handling and optional streaming
if [ "$USE_STREAMING" = true ]; then
    call_openrouter "$MODEL" "$MASTER_PROMPT" --stream
else
    call_openrouter "$MODEL" "$MASTER_PROMPT"
fi

# Check if API call succeeded
if [ $? -eq 0 ]; then
    echo -e "\n---" >&2
    echo "SUCCESS: 'Narrative Designer' analysis complete." >&2
else
    echo "FAILED: 'Narrative Designer' encountered an error." >&2
    exit 1
fi
