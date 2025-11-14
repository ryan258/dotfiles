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

# Shared utils
if [ -f "$DOTFILES_DIR/bin/dhp-utils.sh" ]; then
  source "$DOTFILES_DIR/bin/dhp-utils.sh"
fi

# Source squad configuration helpers if available
if [ -f "$DOTFILES_DIR/bin/dhp-config.sh" ]; then
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/bin/dhp-config.sh"
fi

# Set output directory with fallback
PROJECTS_DIR=$(default_output_dir "$HOME/Documents/AI_Staff_HQ_Outputs/Content/Guides" "DHP_CONTENT_OUTPUT_DIR")

# Persona playbook discovery
if [ -z "${PERSONA_PLAYBOOK_FILE:-}" ]; then
    if [ -f "$DOTFILES_DIR/docs/personas.md" ]; then
        PERSONA_PLAYBOOK_FILE="$DOTFILES_DIR/docs/personas.md"
    elif [ -f "$DOTFILES_DIR/PERSONAS.md" ]; then
        PERSONA_PLAYBOOK_FILE="$DOTFILES_DIR/PERSONAS.md"
    else
        PERSONA_PLAYBOOK_FILE="$DOTFILES_DIR/docs/personas.md"
    fi
fi

# Source context library
if [ -f "$DOTFILES_DIR/bin/dhp-context.sh" ]; then
  source "$DOTFILES_DIR/bin/dhp-context.sh"
fi

# Helpers --------------------------------------------------------------
slugify() {
    local value="$1"
    value=$(echo "$value" | tr '[:upper:]' '[:lower:]')
    value=$(echo "$value" | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')
    echo "$value"
}

load_persona_block() {
    local persona_slug="$1"
    local file="$2"
    [ -f "$file" ] || return 1
    awk -v target="$persona_slug" '
    function slugify(str) {
        gsub(/^[ \t]+|[ \t]+$/, "", str)
        str=tolower(str)
        gsub(/[^a-z0-9]+/, "-", str)
        gsub(/^-+|-+$/, "", str)
        return str
    }
    /^##[ \t]+/ {
        current=slugify(substr($0,3))
        if (capture && current != target) {
            exit
        }
        capture = (current == target)
        next
    }
    capture { print }
    ' "$file"
}

# Parse flags
USE_CONTEXT=false
USE_STREAMING=false
PARAM_TEMPERATURE=""
PARAM_MAX_TOKENS=""
PERSONA_NAME=""
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
        --temperature)
            PARAM_TEMPERATURE="$2"
            shift 2
            ;;
        --max-tokens)
            PARAM_MAX_TOKENS="$2"
            shift 2
            ;;
        --persona)
            PERSONA_NAME="$2"
            shift 2
            ;;
        *)
            echo "Unknown flag: $1" >&2
            exit 1
            ;;
    esac
done

# --- 2. VALIDATION ---
# Check for required tools
validate_dependencies curl jq

# Check for Environment Variables
ensure_api_key OPENROUTER_API_KEY

# Load model from .env, fallback to legacy variable, then default
MODEL="${CONTENT_MODEL:-${DHP_CONTENT_MODEL:-qwen/qwen3-coder:free}}"

# Check if the user provided a brief
if [ -z "$1" ]; then
    echo "Usage: $0 [--context|--full-context] [--persona NAME] [--stream] \"Topic for your new guide\"" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --context       Include minimal local context (git, top tasks)" >&2
    echo "  --full-context  Include full context (journal, todos, README, git)" >&2
    echo "  --persona NAME  Inject persona playbook from docs/personas.md" >&2
    echo "  --stream        Enable real-time streaming output" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  $0 \"Guide on productivity with AI\"" >&2
    echo "  $0 --context --persona calm-coach \"Best practices for bash scripting\"" >&2
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
PERSONA_PLAYBOOK=""
if [ -n "$PERSONA_NAME" ]; then
    if [ ! -f "$PERSONA_PLAYBOOK_FILE" ]; then
        echo "Error: Persona file not found at $PERSONA_PLAYBOOK_FILE" >&2
        exit 1
    fi
    PERSONA_SLUG=$(slugify "$PERSONA_NAME")
    PERSONA_PLAYBOOK=$(load_persona_block "$PERSONA_SLUG" "$PERSONA_PLAYBOOK_FILE")
    if [ -z "$PERSONA_PLAYBOOK" ]; then
        echo "Error: Persona '$PERSONA_NAME' not found in $PERSONA_PLAYBOOK_FILE" >&2
        exit 1
    fi
fi

STAFF_TO_LOAD=()
if command -v get_squad_staff >/dev/null 2>&1; then
    while IFS= read -r staff; do
        [ -n "$staff" ] && STAFF_TO_LOAD+=("$staff")
    done < <(get_squad_staff "content" 2>/dev/null)
fi
if [ ${#STAFF_TO_LOAD[@]} -eq 0 ]; then
    STAFF_TO_LOAD=(
        "strategy/chief-of-staff.yaml"
        "strategy/market-analyst.yaml"
        "producers/copywriter.yaml"
    )
fi
mkdir -p "$PROJECTS_DIR"
SLUG=$(echo "$USER_BRIEF" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | cut -c 1-50)
OUTPUT_FILE="$PROJECTS_DIR/${SLUG}.md"

echo "Activating 'AI-Staff-HQ' for Content Workflow via OpenRouter (Model: $MODEL)..."
echo "Brief: $USER_BRIEF"
[ -n "$PERSONA_NAME" ] && echo "Persona: $PERSONA_NAME"
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

$(if [ -n "$PERSONA_PLAYBOOK" ]; then echo -e "\n**PERSONA PLAYBOOK (${PERSONA_NAME}):**\n$PERSONA_PLAYBOOK\n\nApply this perspective consistently across the outline, tone, and recommendations.\n"; fi)

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
    call_openrouter "$MODEL" "$PROMPT_CONTENT" "--stream" "dhp-content" | tee "$OUTPUT_FILE"
else
    call_openrouter "$MODEL" "$PROMPT_CONTENT" "" "dhp-content" | tee "$OUTPUT_FILE"
fi

# Check if API call succeeded
if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    echo -e "\n---"
    echo "SUCCESS: 'First-Draft Skeleton' saved to $OUTPUT_FILE"
else
    echo "FAILED: Content generation encountered an error."
    exit 1
fi
