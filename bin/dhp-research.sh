#!/bin/bash
set -e

# dhp-research.sh - Head Librarian dispatcher
# Research organization, source summarization, knowledge synthesis

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
MODEL="${RESEARCH_MODEL:-${DHP_STRATEGY_MODEL:-z-ai/glm-4.5-air:free}}"
STAFF_FILE="$AI_STAFF_DIR/staff/strategy/academic-researcher.yaml"
if [ ! -f "$STAFF_FILE" ]; then
    echo "Error: Academic Researcher specialist not found at $STAFF_FILE" >&2; exit 1
fi

# --- 5. OUTPUT SETUP ---
OUTPUT_DIR=$(default_output_dir "$HOME/Documents/AI_Staff_HQ_Outputs/Personal_Development/Research" "DHP_RESEARCH_OUTPUT_DIR")
mkdir -p "$OUTPUT_DIR"
SLUG=$(echo "$PIPED_CONTENT" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | cut -c 1-50)
OUTPUT_FILE="$OUTPUT_DIR/${SLUG}.md"

echo "Activating 'Academic Researcher' via OpenRouter (Model: $MODEL)..." >&2
echo "Saving to: $OUTPUT_FILE" >&2
echo "---" >&2

# --- 6. PROMPT ASSEMBLY ---
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

# --- 7. EXECUTION ---
if [ "$USE_STREAMING" = true ]; then
    call_openrouter "$MODEL" "$MASTER_PROMPT" --stream | tee "$OUTPUT_FILE"
else
    call_openrouter "$MODEL" "$MASTER_PROMPT" | tee "$OUTPUT_FILE"
fi

# Check if API call succeeded
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo -e "\n---" >&2
    echo "SUCCESS: 'Academic Researcher' research complete." >&2
else
    echo "FAILED: 'Academic Researcher' encountered an error." >&2
    exit 1
fi
