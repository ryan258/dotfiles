#!/bin/bash
set -e

# dhp-stoic.sh - Stoic Coach dispatcher (Swarm Edition)
# Mindset coaching, reflections, journaling prompts

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

# --- 1. SETUP ---
dhp_setup_env

# --- 2. FLAG PARSING ---
dhp_parse_flags "$@"
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
MODEL="${STOIC_MODEL:-${FALLBACK_GENERAL:-mistralai/mistral-small-3.1-24b-instruct:free}}"
OUTPUT_DIR=$(default_output_dir "$HOME/Documents/AI_Staff_HQ_Outputs/Personal_Development/Stoic_Coaching" "DHP_STOIC_OUTPUT_DIR")
mkdir -p "$OUTPUT_DIR"
SLUG=$(echo "$PIPED_CONTENT" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | cut -c 1-50)
OUTPUT_FILE="$OUTPUT_DIR/${SLUG}.md"

echo "Activating 'AI-Staff-HQ' Swarm for Stoic Coaching..." >&2
echo "Model: $MODEL"
echo "Saving to: $OUTPUT_FILE" >&2
echo "---" >&2

# --- 5. BUILD ENHANCED BRIEF ---
ENHANCED_BRIEF="$PIPED_CONTENT

--- STOICO COACHING OBJECTIVES ---
Provide guidance based on Stoic philosophy:
1. Reframe the user's situation through Stoic principles (View from Above, Dichotomy of Control)
2. Distinguish clearly between what is within control vs. outside it
3. Recommend practical actions, exercises, or reflections
4. Cite relevant teachings (Marcus Aurelius, Seneca, Epictetus) where appropriate

DELIVERABLE: A compassionate but firm coaching response, practical and grounded."

# --- 6. EXECUTE SWARM ORCHESTRATION ---
PYTHON_CMD="uv run --project \"$AI_STAFF_DIR\" python \"$DOTFILES_DIR/bin/dhp-swarm.py\""

if [ -n "$MODEL" ]; then
    PYTHON_CMD="$PYTHON_CMD --model \"$MODEL\""
fi

if [ -n "$PARAM_TEMPERATURE" ]; then
    PYTHON_CMD="$PYTHON_CMD --temperature $PARAM_TEMPERATURE"
else
    # Stoic advice should be calm and reasoned (lower temp)
    PYTHON_CMD="$PYTHON_CMD --temperature 0.3"
fi

PYTHON_CMD="$PYTHON_CMD --parallel --max-parallel 5"
PYTHON_CMD="$PYTHON_CMD --auto-approve"

echo "Executing stoic swarm..." >&2
echo "$ENHANCED_BRIEF" | eval "$PYTHON_CMD" | tee "$OUTPUT_FILE"

if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    echo -e "\n---" >&2
    echo "✓ SUCCESS: Stoic guidance completed via swarm" >&2
else
    echo "✗ FAILED: Swarm orchestration encountered an error" >&2
    exit 1
fi
