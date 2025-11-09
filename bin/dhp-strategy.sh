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

# Use strategic model (can be same as content or creative)
STRATEGY_MODEL="${DHP_STRATEGY_MODEL:-${DHP_CONTENT_MODEL}}"
if [ -z "$STRATEGY_MODEL" ]; then
    echo "Error: No model configured for strategy dispatcher." >&2
    echo "Please set DHP_STRATEGY_MODEL or DHP_CONTENT_MODEL in your .env file." >&2
    exit 1
fi

if [ ! -d "$AI_STAFF_DIR" ]; then
    echo "Error: AI Staff directory not found at $AI_STAFF_DIR" >&2
    exit 1
fi

# --- 3. PREPARE PROMPT ---
STAFF_FILE="$AI_STAFF_DIR/staff/strategy/chief-of-staff.yaml"

if [ ! -f "$STAFF_FILE" ]; then
    echo "Error: Chief of Staff specialist not found at $STAFF_FILE" >&2
    exit 1
fi

# Read input from stdin
PIPED_CONTENT=$(cat -)

if [ -z "$PIPED_CONTENT" ]; then
    echo "Usage: <input> | $0 [--stream]" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --stream    Enable real-time streaming output" >&2
    echo "" >&2
    echo "Error: No input provided via stdin." >&2
    exit 1
fi

echo "Activating 'Chief of Staff' via OpenRouter (Model: $STRATEGY_MODEL)..." >&2
echo "---" >&2

# --- 4. BUILD MASTER PROMPT ---
MASTER_PROMPT_FILE=$(mktemp)
trap 'rm -f "$MASTER_PROMPT_FILE"' EXIT

# Load Chief of Staff persona
cat "$STAFF_FILE" > "$MASTER_PROMPT_FILE"

# Add the analysis request
echo -e "\n\n--- ANALYSIS REQUEST ---

You are the Chief of Staff from AI-Staff-HQ. Analyze the following information and provide strategic insights, patterns, and actionable recommendations.

**INPUT:**
---
$PIPED_CONTENT
---

**DELIVERABLE:**
Provide a clear, actionable analysis with:
1. **Key Insights:** Main patterns and observations
2. **Strategic Recommendations:** Specific next actions
3. **Potential Risks/Opportunities:** What to watch for

Keep your response concise and actionable.
" >> "$MASTER_PROMPT_FILE"

# --- 5. EXECUTE API CALL ---
PROMPT_CONTENT=$(cat "$MASTER_PROMPT_FILE")

# Execute the API call with error handling and optional streaming
if [ "$USE_STREAMING" = true ]; then
    call_openrouter "$STRATEGY_MODEL" "$PROMPT_CONTENT" --stream
else
    call_openrouter "$STRATEGY_MODEL" "$PROMPT_CONTENT"
fi

# Check if API call succeeded
if [ $? -eq 0 ]; then
    echo -e "\n---" >&2
    echo "SUCCESS: 'Chief of Staff' analysis complete." >&2
else
    echo "FAILED: 'Chief of Staff' encountered an error." >&2
    exit 1
fi
