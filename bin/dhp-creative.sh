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
PROJECTS_DIR=$(default_output_dir "$HOME/Projects/creative-writing" CREATIVE_OUTPUT_DIR)

if [ ! -d "$AI_STAFF_DIR" ]; then
    echo "Error: AI Staff directory not found at $AI_STAFF_DIR" >&2
    exit 1
fi

# --- 5. THE "GATLIN GUN" ASSEMBLY ---
STAFF_TO_LOAD=()
if command -v get_squad_staff >/dev/null 2>&1; then
    while IFS= read -r staff; do
        [ -n "$staff" ] && STAFF_TO_LOAD+=("$staff")
    done < <(get_squad_staff "creative" 2>/dev/null)
fi
if [ ${#STAFF_TO_LOAD[@]} -eq 0 ]; then
    STAFF_TO_LOAD=(
        "strategy/chief-of-staff.yaml"
        "producers/narrative-designer.yaml"
        "strategy/creative-strategist.yaml"
        "health-lifestyle/meditation-instructor.yaml"
    )
fi
mkdir -p "$PROJECTS_DIR"
SLUG=$(echo "$USER_BRIEF" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | cut -c 1-50)
OUTPUT_FILE="$PROJECTS_DIR/${SLUG}.md"

echo "Activating 'AI-Staff-HQ' via OpenRouter (Model: $MODEL)..."
echo "Brief: $USER_BRIEF"
echo "Saving to: $OUTPUT_FILE"
echo "---"

# --- 6. THE "MASTER PROMPT" (THE PAYLOAD) ---
MASTER_PROMPT_FILE=$(mktemp)
trap 'rm -f "$MASTER_PROMPT_FILE"' EXIT

# 6a. Add the "Chief of Staff" first
cat "$AI_STAFF_DIR/staff/${STAFF_TO_LOAD[0]}" > "$MASTER_PROMPT_FILE"

# 6b. Add the rest of the team
for ((i=1; i<${#STAFF_TO_LOAD[@]}; i++)); do
    STAFF_FILE="$AI_STAFF_DIR/staff/${STAFF_TO_LOAD[$i]}"
    echo -e "\n\n--- SUPPORTING AGENT: $(basename "$STAFF_FILE") ---\n\n" >> "$MASTER_PROMPT_FILE"
    cat "$STAFF_FILE" >> "$MASTER_PROMPT_FILE"
done

# 6c. Add the final instructions
echo -e "\n\n--- MASTER INSTRUCTION (THE DISPATCH) ---

You are the **Chief of Staff**. Your supporting agent profiles are loaded above.

Your mission is to coordinate this team to execute on the following user brief and deliver a 'First-Pass Story Package' in a single, clean markdown response.

**USER BRIEF:**
\"$USER_BRIEF\"

**YOUR COORDINATION PLAN:**
1.  **Assign to \`narrative-designer\`:** Generate a 3-Act structure and 5-7 key story beats.
2.  **Assign to \`persona-architect\`:** Generate a character profile for the protagonist.
3.  **Assign to \`sound-designer\` (acting as The Sensorium):** Generate 3 'sensory blocks' of ambient horror for this concept. Specifically focus on sound, smell, and the *feeling* of the "echoes" mentioned in the brief.

**DELIVERABLE:**
Return a single, well-formatted markdown document. Do not speak *as* the team, speak *as* the Chief of Staff presenting the team's coordinated work.
" >> "$MASTER_PROMPT_FILE"

# --- 7. FIRE! ---
PROMPT_CONTENT=$(cat "$MASTER_PROMPT_FILE")

if [ "$USE_STREAMING" = true ]; then
    DHP_TEMPERATURE="$PARAM_TEMPERATURE" DHP_MAX_TOKENS="$PARAM_MAX_TOKENS" call_openrouter "$MODEL" "$PROMPT_CONTENT" --stream | tee "$OUTPUT_FILE"
else
    DHP_TEMPERATURE="$PARAM_TEMPERATURE" DHP_MAX_TOKENS="$PARAM_MAX_TOKENS" call_openrouter "$MODEL" "$PROMPT_CONTENT" | tee "$OUTPUT_FILE"
fi

# Check if API call succeeded
if [ $? -eq 0 ]; then
    echo -e "\n---"
    echo "SUCCESS: 'First-Pass Story Package' saved to $OUTPUT_FILE"
else
    echo "FAILED: Story generation encountered an error."
    exit 1
fi
