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
        if (capture && index(current,target) != 1) {
            exit
        }
        if (current == target || index(current,target)==1) {
            capture = 1
        } else {
            capture = 0
        }
        next
    }
    capture { print }
    ' "$file"
}

# Parse flags
USE_CONTEXT=false
USE_STREAMING=false
USE_VERBOSE=false
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
        --verbose)
            USE_VERBOSE=true
            shift
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
    echo "Usage: $0 [options] \"Topic for your new guide\"" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --context       Include minimal local context (git, top tasks)" >&2
    echo "  --full-context  Include full context (journal, todos, README, git)" >&2
    echo "  --persona NAME  Inject persona playbook from docs/personas.md" >&2
    echo "  --verbose       Show detailed progress (wave counts, specialist names, timings)" >&2
    echo "  --stream        Stream task outputs as JSON events" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  $0 \"Guide on productivity with AI\"" >&2
    echo "  $0 --context --persona calm-coach \"Best practices for bash scripting\"" >&2
    echo "  $0 --verbose --stream --context \"Advanced Git workflows\"" >&2
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

# --- 4. PREPARE OUTPUT ---
mkdir -p "$PROJECTS_DIR"
SLUG=$(echo "$USER_BRIEF" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | cut -c 1-50)
OUTPUT_FILE="$PROJECTS_DIR/${SLUG}.md"

echo "Activating 'AI-Staff-HQ' Swarm Orchestration for Content Workflow..."
echo "Brief: $USER_BRIEF"
[ -n "$PERSONA_NAME" ] && echo "Persona: $PERSONA_NAME"
echo "Model: $MODEL"
echo "Saving to: $OUTPUT_FILE"
echo "---"

# --- 5. GATHER CONTEXT (if requested) ---
LOCAL_CONTEXT=""
if [ "$USE_CONTEXT" = true ] && command -v gather_context &> /dev/null; then
    echo "Gathering local context..." >&2
    LOCAL_CONTEXT=$(gather_context "${CONTEXT_MODE:---minimal}")
fi

# --- 6. BUILD ENHANCED BRIEF ---
ENHANCED_BRIEF="$USER_BRIEF"

# Add context if available
if [ -n "$LOCAL_CONTEXT" ]; then
    ENHANCED_BRIEF="$ENHANCED_BRIEF

--- LOCAL CONTEXT (Automatically Injected) ---
$LOCAL_CONTEXT

Use this context to:
- Avoid duplicating recent blog topics
- Reference related tasks or projects
- Align with current git branch/project work
- Build on recent journal themes"
fi

# Add persona if specified
if [ -n "$PERSONA_PLAYBOOK" ]; then
    ENHANCED_BRIEF="$ENHANCED_BRIEF

--- PERSONA PLAYBOOK ($PERSONA_NAME) ---
$PERSONA_PLAYBOOK

Apply this perspective consistently across the outline, tone, and recommendations."
fi

# Add content-specific instructions
ENHANCED_BRIEF="$ENHANCED_BRIEF

--- CONTENT REQUIREMENTS ---
Deliver a 'First-Draft Skeleton' for a new evergreen guide:
1. Research the topic to identify key questions, search intent, and related concepts
2. Create a well-organized outline with section headers and brief descriptions
3. Format as Hugo-ready markdown with complete front matter (title, date, draft: true)

DELIVERABLE: Return a single, well-formatted Hugo markdown document."

# --- 7. EXECUTE SWARM ORCHESTRATION ---

# Build Python wrapper command
PYTHON_CMD="uv run --project \"$AI_STAFF_DIR\" python \"$DOTFILES_DIR/bin/dhp-swarm.py\""

# Add model override if specified
if [ -n "$MODEL" ]; then
    PYTHON_CMD="$PYTHON_CMD --model \"$MODEL\""
fi

# Add temperature if specified
if [ -n "$TEMPERATURE" ]; then
    PYTHON_CMD="$PYTHON_CMD --temperature $TEMPERATURE"
fi

# Add parallel execution flags (default: enabled)
PYTHON_CMD="$PYTHON_CMD --parallel --max-parallel 5"

# Auto-approve (non-interactive)
PYTHON_CMD="$PYTHON_CMD --auto-approve"

if [ "$USE_VERBOSE" = "true" ]; then
    PYTHON_CMD="$PYTHON_CMD --verbose"
fi

if [ "$USE_STREAMING" = "true" ]; then
    PYTHON_CMD="$PYTHON_CMD --stream"
fi

# Execute swarm orchestration
echo "Executing swarm orchestration..." >&2
echo "$ENHANCED_BRIEF" | eval "$PYTHON_CMD" | tee "$OUTPUT_FILE"

# Check if swarm execution succeeded
if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    echo -e "\n---"
    echo "✓ SUCCESS: Content generated via swarm orchestration"
    echo "  Output: $OUTPUT_FILE"
else
    echo "✗ FAILED: Swarm orchestration encountered an error"
    exit 1
fi
