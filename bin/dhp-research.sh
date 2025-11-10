#!/bin/bash
set -e

# dhp-research.sh - Head Librarian dispatcher
# Research organization, source summarization, knowledge synthesis

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
MODEL="${RESEARCH_MODEL:-${DHP_STRATEGY_MODEL:-z-ai/glm-4.5-air:free}}"

STAFF_FILE="$AI_STAFF_DIR/staff/strategy/academic-researcher.yaml"
if [ ! -f "$STAFF_FILE" ]; then
    echo "Error: Academic Researcher specialist not found at $STAFF_FILE" >&2; exit 1
fi

PIPED_CONTENT=$(cat -)
if [ -z "$PIPED_CONTENT" ]; then
    echo "Usage: <input> | $0 [--stream]" >&2
    echo "Options:" >&2
    echo "  --stream    Enable real-time streaming output" >&2
    exit 1
fi

echo "Activating 'Academic Researcher' via OpenRouter (Model: $MODEL)..." >&2
echo "---" >&2

MASTER_PROMPT=$(cat "$STAFF_FILE")
MASTER_PROMPT+="

--- RESEARCH REQUEST ---
$PIPED_CONTENT

Provide research synthesis with:
1. Key themes and main ideas
2. Structured organization of concepts
3. Important connections or patterns
4. Suggested next research directions
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
    echo "SUCCESS: 'Academic Researcher' research complete." >&2
else
    echo "FAILED: 'Academic Researcher' encountered an error." >&2
    exit 1
fi
