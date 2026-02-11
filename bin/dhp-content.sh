#!/usr/bin/env bash
set -euo pipefail

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

# Note: dhp-content.sh has unique requirements (Personas, Context) that
# go beyond validate_dependencies. We handle those here before dispatching.

# --- 1. SETUP ---
dhp_setup_env

# Helpers for this script specifically
slugify_local() {
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

# --- 2. CUSTOM FLAG PARSING ---
# We use a custom parser here because of --persona and --context which are unique to content
USE_CONTEXT=false
USE_STREAMING=false
USE_VERBOSE=false
PERSONA_NAME=""
REMAINING_ARGS_LOCAL=()
CONTEXT_MODE=""
PARAM_TEMPERATURE="${PARAM_TEMPERATURE:-}"

while [[ "$#" -gt 0 ]]; do
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
            if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
                echo "Error: --persona requires a value." >&2
                exit 1
            fi
            PERSONA_NAME="$2"
            shift 2
            ;;
        --temperature)
            if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
                echo "Error: --temperature requires a numeric value." >&2
                exit 1
            fi
            PARAM_TEMPERATURE="$2"
            shift 2
            ;;
        --brain)
            USE_BRAIN=true
            shift
            ;;
        --)
            shift
            while [[ "$#" -gt 0 ]]; do
                REMAINING_ARGS_LOCAL+=("$1")
                shift
            done
            ;;
        --*)
            echo "Error: Unknown flag: $1" >&2
            exit 1
            ;;
        *)
            REMAINING_ARGS_LOCAL+=("$1")
            shift
            ;;
    esac
done

# Restore args for dhp_get_input
if [ ${#REMAINING_ARGS_LOCAL[@]} -gt 0 ]; then
    set -- "${REMAINING_ARGS_LOCAL[@]}"
else
    set --
fi

# --- 3. INPUT GATHERING ---
validate_dependencies curl jq
ensure_api_key OPENROUTER_API_KEY
dhp_get_input "$@"

if [ -z "$PIPED_CONTENT" ]; then
    echo "Usage: $0 [options] \"Topic for your new guide\"" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --context       Include minimal local context (git, top tasks)" >&2
    echo "  --full-context  Include full context (journal, todos, README, git)" >&2
    echo "  --persona NAME  Inject persona playbook from docs/personas.md" >&2
    echo "  --verbose       Show detailed progress (wave counts, specialist names, timings)" >&2
    echo "  --stream        Stream task outputs as JSON events" >&2
    echo "" >&2
    exit 1
fi

# --- 4. PREPARE CONTEXT & PERSONA for System Brief ---

# Persona
PERSONA_BLOCK=""
if [ -n "$PERSONA_NAME" ]; then
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

    if [ ! -f "$PERSONA_PLAYBOOK_FILE" ]; then
        echo "Error: Persona file not found at $PERSONA_PLAYBOOK_FILE" >&2
        exit 1
    fi
    PERSONA_SLUG=$(slugify_local "$PERSONA_NAME")
    PERSONA_DATA=$(load_persona_block "$PERSONA_SLUG" "$PERSONA_PLAYBOOK_FILE")
    if [ -z "$PERSONA_DATA" ]; then
        echo "Error: Persona '$PERSONA_NAME' not found in $PERSONA_PLAYBOOK_FILE" >&2
        exit 1
    fi
    PERSONA_BLOCK="
--- PERSONA PLAYBOOK ($PERSONA_NAME) ---
$PERSONA_DATA

Apply this perspective consistently across the outline, tone, and recommendations."
fi

# Context
CONTEXT_BLOCK=""
# Source context library if needed
if [ "$USE_CONTEXT" = true ]; then
    if [ -f "$DOTFILES_DIR/bin/dhp-context.sh" ]; then
        source "$DOTFILES_DIR/bin/dhp-context.sh"
        if command -v gather_context &> /dev/null; then
            echo "Gathering local context..." >&2
            LOCAL_CONTEXT=$(gather_context "${CONTEXT_MODE:---minimal}")
            if [ -n "$LOCAL_CONTEXT" ]; then
                CONTEXT_BLOCK="
--- LOCAL CONTEXT (Automatically Injected) ---
$LOCAL_CONTEXT

Use this context to:
- Avoid duplicating recent blog topics
- Reference related tasks or projects
- Align with current git branch/project work
- Build on recent journal themes"
            fi
        fi
    fi
fi

# --- 5. DISPATCH ---

# Construct the FULL System Brief
SYSTEM_BRIEF_CONTENT="$CONTEXT_BLOCK
$PERSONA_BLOCK

--- CONTENT REQUIREMENTS ---
Deliver a 'First-Draft Skeleton' for a new evergreen guide:
1. Research the topic to identify key questions, search intent, and related concepts
2. Create a well-organized outline with section headers and brief descriptions
3. Format as Hugo-ready markdown with complete front matter (title, date, draft: true)

DELIVERABLE: Return a single, well-formatted Hugo markdown document."

# Re-export manual flags to global vars for dhp_dispatch usage
export USE_VERBOSE
export USE_STREAMING
export PARAM_TEMPERATURE
export USE_BRAIN

dhp_dispatch \
    "Content Workflow" \
    "moonshotai/kimi-k2:free" \
    "$HOME/Documents/AI_Staff_HQ_Outputs/Content/Guides" \
    "CONTENT_MODEL" \
    "DHP_CONTENT_OUTPUT_DIR" \
    "$SYSTEM_BRIEF_CONTENT" \
    "" \
    "$@"
