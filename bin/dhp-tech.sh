#!/bin/bash
set -e # Exit immediately if a command fails

# --- 1. CONFIGURATION ---
DOTFILES_DIR="$HOME/dotfiles"
AI_STAFF_DIR="$DOTFILES_DIR/ai-staff-hq"

# Source environment variables
if [ -f "$DOTFILES_DIR/.env" ]; then
  source "$DOTFILES_DIR/.env"
fi

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

# --- 2. VALIDATION ---
# Check for required tools
if ! command -v curl &> /dev/null; then
    echo "Error: 'curl' is not installed. Please install it." >&2
    exit 1
fi
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed. Please install it." >&2
    exit 1
fi

# Check for Environment Variables
if [ -z "$OPENROUTER_API_KEY" ]; then
    echo "Error: OPENROUTER_API_KEY is not set." >&2
    echo "Please add it to your .env file and source it." >&2
    exit 1
fi

# Load model from .env, fallback to legacy variable, then default
MODEL="${TECH_MODEL:-${DHP_TECH_MODEL:-deepseek/deepseek-r1-0528:free}}"

if [ ! -d "$AI_STAFF_DIR" ]; then
    echo "Error: AI Staff directory not found at $AI_STAFF_DIR" >&2
    exit 1
fi

# --- 3. THE "GATLIN GUN" ASSEMBLY ---
STAFF_FILE="$AI_STAFF_DIR/staff/technical/automation-specialist.yaml"
PIPED_CONTENT=$(cat -)

if [ -z "$PIPED_CONTENT" ]; then
    echo "Usage: cat <your_script.sh> | $0 [--stream]" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --stream    Enable real-time streaming output" >&2
    echo "" >&2
    echo "Error: No input provided via stdin." >&2
    exit 1
fi

echo "Activating 'The Technician' via OpenRouter (Model: $MODEL)..." >&2
echo "---" >&2

# --- 4. THE "MASTER PROMPT" (THE PAYLOAD) ---
MASTER_PROMPT_FILE=$(mktemp)
trap 'rm -f "$MASTER_PROMPT_FILE"' EXIT

# 4a. Add the "Technician" persona
cat "$STAFF_FILE" > "$MASTER_PROMPT_FILE"

# 4b. Add the final instructions and the user's piped-in code
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

# --- 5. FIRE! ---

# Read the master prompt content
PROMPT_CONTENT=$(cat "$MASTER_PROMPT_FILE")

# Execute the API call with error handling and optional streaming
if [ "$USE_STREAMING" = true ]; then
    call_openrouter "$MODEL" "$PROMPT_CONTENT" --stream
else
    call_openrouter "$MODEL" "$PROMPT_CONTENT"
fi

# Check if API call succeeded
if [ $? -eq 0 ]; then
    echo -e "\n---" >&2
    echo "SUCCESS: 'The Technician' has completed the analysis." >&2
else
    echo "FAILED: 'The Technician' encountered an error." >&2
    exit 1
fi
