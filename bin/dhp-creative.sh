#!/bin/bash
set -e # Exit immediately if a command fails

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

# --- 1. SETUP ---
dhp_setup_env

# Source squad configuration helpers if available
if [ -f "$DOTFILES_DIR/bin/dhp-config.sh" ]; then
    # shellcheck disable=SC1090
    source "$DOTFILES_DIR/bin/dhp-config.sh"
fi

# --- 2. FLAG PARSING ---
dhp_parse_flags "$@"
# After dhp_parse_flags, the remaining arguments are in "$@"
set -- "$@"

# --- 3. VALIDATION & INPUT ---
validate_dependencies curl jq
ensure_api_key OPENROUTER_API_KEY

dhp_get_input "$@"
USER_BRIEF="$PIPED_CONTENT"

if [ -z "$USER_BRIEF" ]; then
    echo "Usage: $0 [--stream] \"Your story idea or logline\"" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --stream         Enable real-time streaming output" >&2
    echo "  --temperature    Set the creativity level (e.g., 0.7)" >&2
    echo "  --max-tokens     Set the maximum response length (e.g., 1024)" >&2
    exit 1
fi

# --- 4. MODEL & STAFF ---
MODEL="${CREATIVE_MODEL:-${DHP_CREATIVE_MODEL:-meta-llama/llama-4-maverick:free}}"
PROJECTS_DIR=$(default_output_dir "$HOME/Documents/AI_Staff_HQ_Outputs/Creative/Stories" "DHP_CREATIVE_OUTPUT_DIR")

if [ ! -d "$AI_STAFF_DIR" ]; then
    echo "Error: AI Staff directory not found at $AI_STAFF_DIR" >&2
    exit 1
fi

# --- 5. THE "GATLIN GUN" ASSEMBLY ---
# --- 6. PREPARE OUTPUT ---
mkdir -p "$PROJECTS_DIR"
SLUG=$(echo "$USER_BRIEF" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | cut -c 1-50)
OUTPUT_FILE="$PROJECTS_DIR/${SLUG}.md"

echo "Activating 'AI-Staff-HQ' Swarm Orchestration for Creative Workflow..."
echo "Brief: $USER_BRIEF"
echo "Model: $MODEL"
echo "Saving to: $OUTPUT_FILE"
echo "---"

# --- 7. BUILD ENHANCED BRIEF ---
ENHANCED_BRIEF="$USER_BRIEF

--- CREATIVE REQUIREMENTS ---
Deliver a 'First-Pass Story Package':
1. Generate a 3-Act structure with 5-7 key story beats
2. Create character profiles for main protagonists
3. Develop sensory blocks for atmosphere (sound, smell, feeling)
4. Include world-building elements as needed

DELIVERABLE: Return a single, well-formatted markdown document with all creative elements integrated."

# --- 8. EXECUTE SWARM ORCHESTRATION ---

# Build Python wrapper command
PYTHON_CMD="uv run python \"$DOTFILES_DIR/bin/dhp-swarm-creative.py\""

# Pass enhanced brief
PYTHON_CMD="$PYTHON_CMD \"$ENHANCED_BRIEF\""

# Add model override if specified
if [ -n "$MODEL" ]; then
    PYTHON_CMD="$PYTHON_CMD --model \"$MODEL\""
fi

# Add temperature (creative work benefits from higher temperature)
if [ -n "$PARAM_TEMPERATURE" ]; then
    PYTHON_CMD="$PYTHON_CMD --temperature $PARAM_TEMPERATURE"
else
    PYTHON_CMD="$PYTHON_CMD --temperature 0.9"  # Default higher for creativity
fi

# Add parallel execution flags
PYTHON_CMD="$PYTHON_CMD --parallel --max-parallel 5"

# Auto-approve (non-interactive)
PYTHON_CMD="$PYTHON_CMD --auto-approve"

# Execute swarm orchestration
echo "Executing creative swarm orchestration..." >&2
eval "$PYTHON_CMD" 2>&1 | tee "$OUTPUT_FILE"

# Check if swarm execution succeeded
if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    echo -e "\n---"
    echo "✓ SUCCESS: Creative content generated via swarm orchestration"
    echo "  Output: $OUTPUT_FILE"
else
    echo "✗ FAILED: Swarm orchestration encountered an error"
    exit 1
fi
