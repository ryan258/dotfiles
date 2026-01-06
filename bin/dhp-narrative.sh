#!/bin/bash
set -e

# dhp-narrative.sh - Narrative Designer dispatcher (Swarm Edition)
# Story structure, plot development, character arcs

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
OUTPUT_DIR=$(default_output_dir "$HOME/Documents/AI_Staff_HQ_Outputs/Creative/Narratives" "DHP_NARRATIVE_OUTPUT_DIR")
mkdir -p "$OUTPUT_DIR"
SLUG=$(echo "$PIPED_CONTENT" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | cut -c 1-50)
OUTPUT_FILE="$OUTPUT_DIR/${SLUG}.md"

echo "Activating 'AI-Staff-HQ' Swarm for Narrative Design..." >&2
echo "Model: $MODEL"
echo "Saving to: $OUTPUT_FILE" >&2
echo "---" >&2

# --- 5. BUILD ENHANCED BRIEF ---
ENHANCED_BRIEF="$PIPED_CONTENT

--- NARRATIVE DESIGN OBJECTIVES ---
Analyze and develop the narrative with focus on:
1. Story structure (3-act, Hero's Journey, or alternative models)
2. Plot coherence and scene progression
3. Character arcs, motivations, and conflicts
4. Key dramatic moments and pacing recommendations

DELIVERABLE: A comprehensive narrative design document tailored to the story concept."

# --- 6. EXECUTE SWARM ORCHESTRATION ---
PYTHON_CMD="uv run --project \"$AI_STAFF_DIR\" python \"$DOTFILES_DIR/bin/dhp-swarm.py\""

if [ -n "$MODEL" ]; then
    PYTHON_CMD="$PYTHON_CMD --model \"$MODEL\""
fi

if [ -n "$PARAM_TEMPERATURE" ]; then
    PYTHON_CMD="$PYTHON_CMD --temperature $PARAM_TEMPERATURE"
else
    # Balance creation with structure
    PYTHON_CMD="$PYTHON_CMD --temperature 0.8"
fi

PYTHON_CMD="$PYTHON_CMD --parallel --max-parallel 5"
PYTHON_CMD="$PYTHON_CMD --auto-approve"

if [ "$USE_VERBOSE" = "true" ]; then
    PYTHON_CMD="$PYTHON_CMD --verbose"
fi

if [ "$USE_STREAMING" = "true" ]; then
    PYTHON_CMD="$PYTHON_CMD --stream"
fi

echo "Executing narrative swarm..." >&2
echo "$ENHANCED_BRIEF" | eval "$PYTHON_CMD" | tee "$OUTPUT_FILE"

if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    echo -e "\n---" >&2
    echo "✓ SUCCESS: Narrative design completed via swarm" >&2
else
    echo "✗ FAILED: Swarm orchestration encountered an error" >&2
    exit 1
fi
