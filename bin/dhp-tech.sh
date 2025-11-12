#!/bin/bash
set -e # Exit immediately if a command fails

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
    echo "  cat <your_script.sh> | $0 [options]" >&2
    echo "  $0 [options] \"Describe the bug in foo()\"" >&2
    echo "Options:" >&2
    echo "  --stream    Enable real-time streaming output" >&2
    echo "" >&2
    echo "Error: No input provided." >&2
    exit 1
fi

# --- 4. MODEL & STAFF ---
MODEL="${TECH_MODEL:-${DHP_TECH_MODEL:-deepseek/deepseek-r1-0528:free}}"
STAFF_FILE="$AI_STAFF_DIR/staff/technical/automation-specialist.yaml"
if [ ! -d "$AI_STAFF_DIR" ]; then
    echo "Error: AI Staff directory not found at $AI_STAFF_DIR" >&2
    exit 1
fi

# --- 5. OUTPUT SETUP ---
OUTPUT_DIR=$(default_output_dir "$HOME/Documents/AI_Staff_HQ_Outputs/Technical/Code_Analysis" "DHP_TECH_OUTPUT_DIR")
mkdir -p "$OUTPUT_DIR"
SLUG=$(echo "$PIPED_CONTENT" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | cut -c 1-50)
OUTPUT_FILE="$OUTPUT_DIR/${SLUG}.md"

echo "Activating 'The Technician' via OpenRouter (Model: $MODEL)..." >&2
echo "Saving to: $OUTPUT_FILE" >&2
echo "---" >&2

# --- 6. PROMPT ASSEMBLY ---
MASTER_PROMPT_FILE=$(mktemp)
trap 'rm -f "$MASTER_PROMPT_FILE"' EXIT

# 6a. Add the "Technician" persona
cat "$STAFF_FILE" > "$MASTER_PROMPT_FILE"

# 6b. Add the final instructions and the user's piped-in code
echo -e "\n\n--- MASTER INSTRUCTION (THE DISPATCH) ---

You are **The Technician**. Your persona is loaded above.

Your mission is to analyze the following script provided by the user, identify the bug or error, explain the cause, and provide the corrected code.

**USER'S SCRIPT (PIPED INPUT):**
---
\`\`\`
$PIPED_CONTENT
\`\`\`
---

**DELIVERABLE:**
Return a single, clean markdown response with three sections:
1.  **Bug Analysis:** A brief explanation of the bug.
2.  **The Fix:** A clear description of the change you made.
3.  **Corrected Code:** The complete, corrected script.
" >> "$MASTER_PROMPT_FILE"

# --- 7. EXECUTION ---
PROMPT_CONTENT=$(cat "$MASTER_PROMPT_FILE")

if [ "$USE_STREAMING" = true ]; then
    call_openrouter "$MODEL" "$PROMPT_CONTENT" "--stream" "dhp-tech" | tee "$OUTPUT_FILE"
else
    call_openrouter "$MODEL" "$PROMPT_CONTENT" "" "dhp-tech" | tee "$OUTPUT_FILE"
fi

# Check if API call succeeded
if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    echo -e "\n---" >&2
    echo "SUCCESS: 'The Technician' has completed the analysis." >&2
else
    echo "FAILED: 'The Technician' encountered an error." >&2
    exit 1
fi
