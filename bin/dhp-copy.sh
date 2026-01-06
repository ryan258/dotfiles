#!/bin/bash
set -e

# dhp-copy.sh - Copywriter dispatcher (Swarm Edition)
# Sales copy, email sequences, landing pages

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

# --- 1. SETUP ---
dhp_setup_env

# --- 2. FLAG PARSING ---
dhp_parse_flags "$@"
set -- "${REMAINING_ARGS[@]}"

# --- 3. VALIDATION & INPUT ---
validate_dependencies curl jq
ensure_api_key OPENROUTER_API_KEY

dhp_get_input "$@"

if [ -z "$PIPED_CONTENT" ]; then
    echo "Usage:" >&2
    echo "  echo \"prompt\" | $0 [options]" >&2
    echo "  $0 [options] \"prompt\"" >&2
    echo "Options:" >&2
    echo "  --verbose   Show detailed progress (wave counts, specialist names, timings)" >&2
    echo "  --stream    Stream task outputs as JSON events" >&2
    exit 1
fi

# --- 4. MODEL & STAFF ---
MODEL="${CREATIVE_MODEL:-${DHP_CREATIVE_MODEL:-meta-llama/llama-4-maverick:free}}"
OUTPUT_DIR=$(default_output_dir "$HOME/Documents/AI_Staff_HQ_Outputs/Creative/Copywriting" "DHP_COPY_OUTPUT_DIR")
mkdir -p "$OUTPUT_DIR"
SLUG=$(echo "$PIPED_CONTENT" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | cut -c 1-50)
OUTPUT_FILE="$OUTPUT_DIR/${SLUG}.md"

echo "Activating 'AI-Staff-HQ' Swarm for Copywriting..." >&2
echo "Model: $MODEL"
echo "Saving to: $OUTPUT_FILE" >&2
echo "---" >&2

# --- 5. BUILD ENHANCED BRIEF ---
ENHANCED_BRIEF="$PIPED_CONTENT

--- COPYWRITING OBJECTIVES ---
Develop compelling copy including:
1. Attention-grabbing headlines and subheadlines
2. Benefit-driven body copy emphasizing value propositions
3. Clear, strong Calls-to-Action (CTA)
4. Persuasive rhetoric tailored to the target audience

DELIVERABLE: A ready-to-use copy document with formatting."

# --- 6. EXECUTION ---
PYTHON_CMD="uv run --project \"$AI_STAFF_DIR\" python \"$DOTFILES_DIR/bin/dhp-swarm.py\""

if [ -n "$MODEL" ]; then
    PYTHON_CMD="$PYTHON_CMD --model \"$MODEL\""
fi

if [ -n "$PARAM_TEMPERATURE" ]; then
    PYTHON_CMD="$PYTHON_CMD --temperature $PARAM_TEMPERATURE"
else
    # Balance persuasion with clarity
    PYTHON_CMD="$PYTHON_CMD --temperature 0.7"
fi

PYTHON_CMD="$PYTHON_CMD --parallel --max-parallel 5"
PYTHON_CMD="$PYTHON_CMD --auto-approve"

if [ "$USE_VERBOSE" = "true" ]; then
    PYTHON_CMD="$PYTHON_CMD --verbose"
fi

if [ "$USE_STREAMING" = "true" ]; then
    PYTHON_CMD="$PYTHON_CMD --stream"
fi

echo "Executing copywriting swarm..." >&2
echo "$ENHANCED_BRIEF" | eval "$PYTHON_CMD" | tee "$OUTPUT_FILE"

if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    echo -e "\n---" >&2
    echo "✓ SUCCESS: Copywriting completed via swarm" >&2
else
    echo "✗ FAILED: Swarm orchestration encountered an error" >&2
    exit 1
fi
