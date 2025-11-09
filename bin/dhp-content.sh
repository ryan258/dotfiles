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

# Set output directory with fallback
if [ -n "$CONTENT_OUTPUT_DIR" ]; then
  PROJECTS_DIR="$CONTENT_OUTPUT_DIR"
elif [ -n "$BLOG_DIR" ]; then
  PROJECTS_DIR="$BLOG_DIR/content/guides"
else
  PROJECTS_DIR="$HOME/Projects/my-ms-ai-blog/content/guides"
fi

# Source context library
if [ -f "$DOTFILES_DIR/bin/dhp-context.sh" ]; then
  source "$DOTFILES_DIR/bin/dhp-context.sh"
fi

# Parse flags
USE_CONTEXT=false
USE_STREAMING=false
while [[ "$1" == --* ]]; do
  case "$1" in
    --context)
      USE_CONTEXT=true
      shift
      ;;
    --full-context)
      USE_CONTEXT=true
      CONTEXT_MODE="--full"
      shift
      ;;
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
if [ -z "$DHP_CONTENT_MODEL" ]; then
    echo "Error: DHP_CONTENT_MODEL is not set." >&2
    echo "Please define it in your .env file." >&2
    exit 1
fi

# Check if the user provided a brief
if [ -z "$1" ]; then
    echo "Usage: $0 [--context|--full-context] [--stream] \"Topic for your new guide\"" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --context       Include minimal local context (git, top tasks)" >&2
    echo "  --full-context  Include full context (journal, todos, README, git)" >&2
    echo "  --stream        Enable real-time streaming output" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  $0 \"Guide on productivity with AI\"" >&2
    echo "  $0 --context \"Best practices for bash scripting\"" >&2
    echo "  $0 --stream --context \"Advanced Git workflows\"" >&2
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
    "strategy/market-analyst.yaml"
    "producers/copywriter.yaml"
)
mkdir -p "$PROJECTS_DIR"
SLUG=$(echo "$USER_BRIEF" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | cut -c 1-50)
OUTPUT_FILE="$PROJECTS_DIR/${SLUG}.md"

echo "Activating 'AI-Staff-HQ' for Content Workflow via OpenRouter (Model: $DHP_CONTENT_MODEL)..."
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
LOCAL_CONTEXT=""
if [ "$USE_CONTEXT" = true ] && command -v gather_context &> /dev/null; then
    LOCAL_CONTEXT=$(gather_context "${CONTEXT_MODE:---minimal}")
fi

echo -e "\n\n--- MASTER INSTRUCTION (THE DISPATCH) ---

You are the **Chief of Staff**. Your supporting agent profiles are loaded above.

Your mission is to coordinate this team to execute on the following user brief and deliver a 'First-Draft Skeleton' for a new evergreen guide.

**USER BRIEF:**
\"$USER_BRIEF\"

$(if [ -n "$LOCAL_CONTEXT" ]; then echo -e "\n**LOCAL CONTEXT (Automatically Injected):**\n$LOCAL_CONTEXT\n\nUse this context to:\n- Avoid duplicating recent blog topics\n- Reference related tasks or projects\n- Align with current git branch/project work\n- Build on recent journal themes\n"; fi)

**YOUR COORDINATION PLAN:**
1.  **Assign to \`market-analyst\` (acting as The Pathfinder):** Research the topic to identify key questions, search intent, and related concepts for a comprehensive guide. The output should be a list of 5-7 core topics or questions to answer.
2.  **Assign to \`copywriter\`:** Using the market analyst's research, generate a 'First-Draft Skeleton' of the guide. The structure should be a well-organized outline with section headers, brief descriptions for each section, and placeholder text where the full content will go.
3.  **Format for Hugo:** The final deliverable must be a single, clean markdown document ready for a Hugo static site. It must include a complete front matter section with \`title\`, \`date\`, and \`draft: true\`.

**DELIVERABLE:**
Return a single, well-formatted Hugo-ready markdown document.
" >> "$MASTER_PROMPT_FILE"

# --- 5. FIRE! ---

# Read the master prompt content
PROMPT_CONTENT=$(cat "$MASTER_PROMPT_FILE")

# Execute the API call with error handling and optional streaming
if [ "$USE_STREAMING" = true ]; then
    call_openrouter "$DHP_CONTENT_MODEL" "$PROMPT_CONTENT" --stream | tee "$OUTPUT_FILE"
else
    call_openrouter "$DHP_CONTENT_MODEL" "$PROMPT_CONTENT" | tee "$OUTPUT_FILE"
fi

# Check if API call succeeded
if [ $? -eq 0 ]; then
    echo -e "\n---"
    echo "SUCCESS: 'First-Draft Skeleton' saved to $OUTPUT_FILE"
else
    echo "FAILED: Content generation encountered an error."
    exit 1
fi
