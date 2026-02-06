#!/usr/bin/env bash
# dhp-shared.sh: Shared library for DHP dispatcher scripts
# This script provides common setup, flag parsing, and input handling functions.
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_DHP_SHARED_LOADED:-}" ]]; then
    return 0
fi
readonly _DHP_SHARED_LOADED=true

# Function to set up the environment for DHP scripts
# Sources .env, dhp-lib.sh, and dhp-utils.sh
dhp_setup_env() {
    local shared_dir
    shared_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$shared_dir/.." && pwd)}"
    AI_STAFF_DIR="$DOTFILES_DIR/ai-staff-hq"

    # Source environment variables
    if [ -f "$DOTFILES_DIR/.env" ]; then
        source "$DOTFILES_DIR/.env"
    fi

    # Check for API key
    # Check for API key (Warning only, as some models might be local/free)
    if [ -z "${OPENROUTER_API_KEY:-}" ]; then
        echo "Warning: OPENROUTER_API_KEY is not set. Swarm may fail if using paid models." >&2
    fi

    # Source shared libraries
    if [ -f "$DOTFILES_DIR/bin/dhp-lib.sh" ]; then
        source "$DOTFILES_DIR/bin/dhp-lib.sh"
    else
        echo "Error: Shared library dhp-lib.sh not found" >&2
        return 1
    fi

    if [ -f "$DOTFILES_DIR/bin/dhp-utils.sh" ]; then
        source "$DOTFILES_DIR/bin/dhp-utils.sh"
    fi
}

# Function to parse common flags like --stream, --verbose
# Sets global variables: USE_STREAMING, USE_VERBOSE, PARAM_TEMPERATURE, PARAM_MAX_TOKENS
# Stores remaining non-flag arguments in REMAINING_ARGS array for caller to use
# Usage:
#   dhp_parse_flags "$@"
#   set -- "${REMAINING_ARGS[@]}"
dhp_parse_flags() {
    USE_STREAMING="${USE_STREAMING:-false}"
    USE_VERBOSE="${USE_VERBOSE:-false}"
    PARAM_TEMPERATURE="${PARAM_TEMPERATURE:-}"
    PARAM_MAX_TOKENS="${PARAM_MAX_TOKENS:-}"
    USE_BRAIN="${USE_BRAIN:-false}"
    REMAINING_ARGS=()
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --stream)
                USE_STREAMING=true
                shift
                ;;
            --verbose)
                USE_VERBOSE=true
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
            --brain)
                USE_BRAIN=true
                shift
                ;;
            *)
                REMAINING_ARGS+=("$1")
                shift
                ;;
        esac
    done
}


# Function to get input from arguments or stdin
# Returns the input content in the PIPED_CONTENT variable
dhp_get_input() {
    local temp_input="$*"
    if [ -n "$temp_input" ]; then
        PIPED_CONTENT="$temp_input"
    elif [ ! -t 0 ]; then
        PIPED_CONTENT=$(cat)
    else
        PIPED_CONTENT=""
    fi

    # Input validation
    if [ -n "$PIPED_CONTENT" ]; then
        # Check for null bytes
        if [ "$(printf '%s' "$PIPED_CONTENT" | tr -d '\0' | wc -c)" -ne "$(printf '%s' "$PIPED_CONTENT" | wc -c)" ]; then
            echo "Error: Input contains null bytes, which are not allowed." >&2
            return 1
        fi

        # Check for maximum length (e.g., 50KB)
        MAX_INPUT_BYTES=5242880 # 5MB
        INPUT_BYTES=$(echo -n "$PIPED_CONTENT" | wc -c)
        if [ "$INPUT_BYTES" -gt "$MAX_INPUT_BYTES" ]; then
            echo "Error: Input exceeds maximum allowed size of $((MAX_INPUT_BYTES / 1024 / 1024))MB." >&2
            return 1
        fi
    fi
}


# Helper to generate a safe slug from text
slugify() {
    local text="$1"
    # Lowercase, replace non-alphanumeric with -, trim
    echo "$text" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '-' | sed 's/^-//;s/-$//' | cut -c 1-50
}

# Function to save artifact to Brain (Interactive or Auto)
# Usage: dhp_save_artifact "OUTPUT_FILE" "SLUG" "SERVICE_NAME" "TAGS" "PROJECT" "TYPE"
dhp_save_artifact() {
    local output_file="$1"
    local slug="$2"
    local service_name="$3"
    local tags="$4"
    local project="${5:-ai-staff-hq}"
    local type="${6:-generation}"

    local should_save=false

    if [ "$USE_BRAIN" = "true" ]; then
        should_save=true
        echo "🧠 Auto-saving to Hive Mind..." >&2
    else
        # Interactive mode: Check if we are connected to a terminal
        # simple check: -t 1 checks if stdout is a terminal, but we might be piping stdout.
        # check /dev/tty readability.
        if [ -r /dev/tty ] && [ -t 2 ]; then
            # If stdout is captured (not a TTY), show a preview before prompting
            if [ ! -t 1 ] && [ -f "$output_file" ]; then
                echo -e "\n--- OUTPUT PREVIEW (First 20 lines) ---" > /dev/tty
                head -n 20 "$output_file" > /dev/tty
                echo -e "...\n---------------------------------------" > /dev/tty
            fi

            # Read from TTY to bypass stdin which might be used for input
            echo -n "Save to Hive Mind? [y/N] " > /dev/tty
            if read -n 1 -r response < /dev/tty; then
                echo "" > /dev/tty # Newline
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    should_save=true
                    echo "🧠 Interactive save confirmed..." >&2
                fi
            else
                echo "" > /dev/tty
            fi
        fi
    fi

    if [ "$should_save" = "true" ]; then
        if [ -f "$output_file" ]; then
            if ! "$DOTFILES_DIR/bin/dhp-memory" \
                --title "$(tr '[:lower:]' '[:upper:]' <<< "${service_name:0:1}")${service_name:1}: $slug" \
                --tags "$tags" \
                --project "$project" \
                --type "$type" < "$output_file"; then
                if [ "$USE_BRAIN" = "true" ]; then
                    echo "Error: Failed to save to Brain." >&2
                    return 1
                fi
                echo "Warning: Failed to save to Brain." >&2
            fi
        else
            if [ "$USE_BRAIN" = "true" ]; then
                echo "Error: Output file not found, cannot save to Brain." >&2
                return 1
            fi
            echo "Warning: Output file not found, cannot save to Brain." >&2
        fi
    fi
}

# Centralized Dispatcher Function
# Usage: dhp_dispatch "SERVICE_NAME" "DEFAULT_MODEL" "OUTPUT_DIR_BASE" "ENV_MODEL_VAR" "ENV_OUTPUT_VAR" "SYSTEM_BRIEF" "DEFAULT_TEMP" -- "$@"
dhp_dispatch() {
    local service_name="$1"
    local default_model="$2"
    local output_base="$3"
    local env_model_var="$4"
    local env_output_var="$5"
    local system_brief="${6:-}" # Optional system instruction/brief prefix
    local default_temp="${7:-}" # Optional default temperature
    
    # Shift past the configuration arguments to get to the user arguments
    # We expect 7 configuration arguments.
    shift 7 || true

    # 1. Setup & Parsing
    dhp_setup_env
    # Pass the remaining arguments (user args) to the flag parser
    dhp_parse_flags "$@"
    if [ ${#REMAINING_ARGS[@]} -gt 0 ]; then
        set -- "${REMAINING_ARGS[@]}"
    else
        set --
    fi

    # 2. Validation
    validate_dependencies curl jq
    ensure_api_key OPENROUTER_API_KEY
    
    # 3. Input Gathering
    # Only gather input if not already gathered (e.g. by caller like dhp-content.sh)
    if [ -z "${PIPED_CONTENT:-}" ]; then
        dhp_get_input "$@"
    fi
    
    if [ -z "$PIPED_CONTENT" ]; then
        echo "Usage: echo \"input\" | $(basename "$0") [options]" >&2
        echo "   or: $(basename "$0") "input" [options]" >&2
        return 1
    fi

    # 4. Configuration (Model & Output)
    # Primary env var is passed in (e.g., TECH_MODEL); fall back to legacy DHP_* if set.
    local model_primary="${!env_model_var:-}"
    local legacy_var="DHP_${env_model_var}"
    local model_legacy="${!legacy_var:-}"
    local strategy_override="${STRATEGY_MODEL:-${DHP_STRATEGY_MODEL:-}}"
    local default_model_env="${DEFAULT_MODEL:-${DHP_DEFAULT_MODEL:-}}"
    local model_final=""
    if [ -n "$model_primary" ]; then
        model_final="$model_primary"
    elif [ -n "$model_legacy" ]; then
        model_final="$model_legacy"
    elif [ -n "$default_model_env" ]; then
        model_final="$default_model_env"
    elif [ -n "$strategy_override" ]; then
        model_final="$strategy_override"
    else
        model_final="$default_model"
    fi
    
    # Resolve Output Directory
    local output_dir_final
    output_dir_final=$(default_output_dir "$output_base" "$env_output_var")
    mkdir -p "$output_dir_final"
    
    local slug
    slug=$(slugify "$PIPED_CONTENT")
    local output_file="$output_dir_final/${slug}.md"

    # 5. Build Brief
    local enhanced_brief="$PIPED_CONTENT"
    if [ -n "$system_brief" ]; then
        enhanced_brief="$system_brief
        
INPUT:
$PIPED_CONTENT"
    fi

    # 6. Execution Command Construction
    echo "Activating 'AI-Staff-HQ' Swarm for $service_name..." >&2
    echo "Model: $model_final" >&2
    echo "Saving to: $output_file" >&2
    
    # Use array for creating safe command arguments
    local cmd_args=(uv run --project "$AI_STAFF_DIR" python "$DOTFILES_DIR/bin/dhp-swarm.py")
    
    if [ -n "$model_final" ]; then
        cmd_args+=(--model "$model_final")
    fi
    
    # Temperature Logic
    if [ -n "$PARAM_TEMPERATURE" ]; then
        cmd_args+=(--temperature "$PARAM_TEMPERATURE")
    elif [ -n "$default_temp" ]; then
        cmd_args+=(--temperature "$default_temp")
    fi
    
    if [ -n "$PARAM_MAX_TOKENS" ]; then
        cmd_args+=(--max-tokens "$PARAM_MAX_TOKENS")
    fi
    
    cmd_args+=(--parallel --max-parallel 5 --auto-approve)
    
    if [ "$USE_VERBOSE" = "true" ]; then
        cmd_args+=(--verbose)
    fi
    
    if [ "$USE_STREAMING" = "true" ]; then
        cmd_args+=(--stream)
    fi
    
    # 7. Execute safely using array expansion
    echo "$enhanced_brief" | "${cmd_args[@]}" | tee "$output_file"
    local exit_code=${PIPESTATUS[1]} # output of python command
    
    if [ "$exit_code" -eq 0 ]; then
        # Unified interactive/auto-save logic
        dhp_save_artifact "$output_file" "$slug" "$service_name" "dhp,swarm,$service_name" "ai-staff-hq" "generation"

        echo -e "\n---" >&2
        echo "✓ SUCCESS: $service_name completed" >&2
    else
        echo "✗ FAILED: Swarm orchestration encountered an error" >&2
        return 1
    fi

}

export -f dhp_setup_env
export -f dhp_parse_flags
export -f dhp_get_input
export -f slugify
export -f dhp_save_artifact
export -f dhp_dispatch
