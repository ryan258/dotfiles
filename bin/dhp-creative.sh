#!/bin/bash
set -e # Exit immediately if a command fails

# --- 1. CONFIGURATION ---
DOTFILES_DIR="$HOME/dotfiles"
AI_STAFF_DIR="$DOTFILES_DIR/ai-staff-hq"

# Source environment variables
if [ -f "$DOTFILES_DIR/.env" ]; then
  source "$DOTFILES_DIR/.env"
fi

# Set output directory with fallback
if [ -n "$CREATIVE_OUTPUT_DIR" ]; then
  PROJECTS_DIR="$CREATIVE_OUTPUT_DIR"
else
  PROJECTS_DIR="$HOME/Projects/creative-writing"
fi

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
if [ -z "$DHP_CREATIVE_MODEL" ]; then
    echo "Error: DHP_CREATIVE_MODEL is not set." >&2
    echo "Please define it in your .env file." >&2
    exit 1
fi

# Check if the user provided a brief
if [ -z "$1" ]; then
    echo "Usage: $0 \"Your story idea or logline\"" >&2
    exit 1
fi

# Check if the AI_STAFF_DIR exists
if [ ! -d "$AI_STAFF_DIR" ]; then
    echo "Error: AI Staff directory not found at $AI_STAFF_DIR" >&2
    exit 1
fi

# --- 3. THE "GATLIN GUN" ASSEMBLY ---
USER_BRIEF="$1"
STAFF_TO_LOAD=(
    "strategy/chief-of-staff.yaml"
    "producers/narrative-designer.yaml"
    "strategy/creative-strategist.yaml"
    "health-lifestyle/meditation-instructor.yaml"
)
mkdir -p "$PROJECTS_DIR"
SLUG=$(echo "$USER_BRIEF" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | cut -c 1-50)
OUTPUT_FILE="$PROJECTS_DIR/${SLUG}.md"

echo "Activating 'AI-Staff-HQ' via OpenRouter (Model: $DHP_CREATIVE_MODEL)..."
echo "Brief: $USER_BRIEF"
echo "Saving to: $OUTPUT_FILE"
echo "---"

# --- 4. THE "MASTER PROMPT" (THE PAYLOAD) ---
MASTER_PROMPT_FILE=$(mktemp)
trap 'rm -f "$MASTER_PROMPT_FILE"' EXIT

# 4a. Add the "Chief of Staff" first
cat "$AI_STAFF_DIR/staff/${STAFF_TO_LOAD[0]}" > "$MASTER_PROMPT_FILE"

# 4b. Add the rest of the team
for ((i=1; i<${#STAFF_TO_LOAD[@]}; i++)); do
    STAFF_FILE="$AI_STAFF_DIR/staff/${STAFF_TO_LOAD[$i]}"
    echo -e "\n\n--- SUPPORTING AGENT: $(basename "$STAFF_FILE") ---\n\n" >> "$MASTER_PROMPT_FILE"
    cat "$STAFF_FILE" >> "$MASTER_PROMPT_FILE"
done

# 4c. Add the final instructions
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

# --- 5. FIRE! ---

# 5a. Read the master prompt content
PROMPT_CONTENT=$(cat "$MASTER_PROMPT_FILE")

# 5b. Build the JSON payload using jq to ensure it's correctly formatted
JSON_PAYLOAD=$(jq -n \
                  --arg model "$DHP_CREATIVE_MODEL" \
                  --arg prompt "$PROMPT_CONTENT" \
                  '{model: $model, messages: [{role: "user", content: $prompt}]}')

# 5c. Execute the API call and parse the response
curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" | jq -r '.choices[0].message.content' | tee "$OUTPUT_FILE"


echo -e "\n---"
echo "SUCCESS: 'First-Pass Story Package' saved to $OUTPUT_FILE"
