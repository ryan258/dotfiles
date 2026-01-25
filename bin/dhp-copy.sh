#!/bin/bash
set -e

# dhp-copy.sh - Copywriter dispatcher (Swarm Edition)
# Sales copy, email sequences, landing pages

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

# --- 1. SETUP ---
dhp_setup_env

# --- 2. FLAG PARSING ---
# Initialize array to prevent unbound variable error
REMAINING_ARGS=()
dhp_parse_flags "$@"
if [ ${#REMAINING_ARGS[@]} -gt 0 ]; then
    set -- "${REMAINING_ARGS[@]}"
else
    set --
fi

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
MODEL="${CREATIVE_MODEL:-${DHP_CREATIVE_MODEL:-${DEFAULT_MODEL:-xiaomi/mimo-v2-flash:free}}}"
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
# Use array construction to safely handle arguments without eval
CMD_ARGS=(
    "uv" "run"
    "--project" "$AI_STAFF_DIR"
    "python" "$DOTFILES_DIR/bin/dhp-swarm.py"
)

if [ -n "$MODEL" ]; then
    CMD_ARGS+=("--model" "$MODEL")
fi

if [ -n "$PARAM_TEMPERATURE" ]; then
    CMD_ARGS+=("--temperature" "$PARAM_TEMPERATURE")
else
    # Balance persuasion with clarity
    CMD_ARGS+=("--temperature" "0.7")
fi

CMD_ARGS+=("--parallel" "--max-parallel" "5")
CMD_ARGS+=("--auto-approve")

if [ "$USE_VERBOSE" = "true" ]; then
    CMD_ARGS+=("--verbose")
fi

if [ "$USE_STREAMING" = "true" ]; then
    CMD_ARGS+=("--stream")
fi

echo "Executing copywriting swarm..." >&2
echo "$ENHANCED_BRIEF" | "${CMD_ARGS[@]}" | tee "$OUTPUT_FILE"

if [ "${PIPESTATUS[1]}" -eq 0 ]; then
    dhp_save_artifact "$OUTPUT_FILE" "$SLUG" "copywriting" "dhp,copywriting,swarm" "ai-staff-hq" "copy"

    echo -e "\n---" >&2
    echo "✓ SUCCESS: Copywriting completed via swarm" >&2
else
    echo "✗ FAILED: Swarm orchestration encountered an error" >&2
    exit 1
fi
