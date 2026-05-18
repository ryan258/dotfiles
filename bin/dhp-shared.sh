#!/usr/bin/env bash
# dhp-shared.sh: Shared library for DHP dispatcher scripts
# This script provides common setup, flag parsing, and input handling functions.
# NOTE: SOURCED file. Strict mode is inherited from the calling dispatcher.

if [[ -n "${_DHP_SHARED_LOADED:-}" ]]; then
    return 0
fi
readonly _DHP_SHARED_LOADED=true

# Function to set up the environment for DHP scripts
# Sources config.sh, common.sh, dhp-lib.sh, and dhp-utils.sh
dhp_setup_env() {
    local shared_dir
    local config_lib
    local common_lib
    shared_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$shared_dir/.." && pwd)}"
    AI_STAFF_DIR="${AI_STAFF_DIR:-$DOTFILES_DIR/ai-staff-hq}"

    config_lib="$DOTFILES_DIR/scripts/lib/config.sh"
    common_lib="$DOTFILES_DIR/scripts/lib/common.sh"
    if [ -f "$config_lib" ]; then
        # shellcheck disable=SC1090
        source "$config_lib"
    else
        echo "Error: configuration library not found at $config_lib" >&2
        return 1
    fi

    if [ -f "$common_lib" ]; then
        # shellcheck disable=SC1090
        source "$common_lib"
    else
        echo "Error: common library not found at $common_lib" >&2
        return 1
    fi

    # Check for API key (Warning only, as some models might be local/free)
    if [ -z "${OPENROUTER_API_KEY:-}" ]; then
        echo "Warning: OPENROUTER_API_KEY is not set. Swarm may fail if using paid models." >&2
    fi

    # Source shared libraries
    if [ -f "$DOTFILES_DIR/bin/dhp-lib.sh" ]; then
        # shellcheck disable=SC1090
        source "$DOTFILES_DIR/bin/dhp-lib.sh"
    else
        echo "Error: Shared library dhp-lib.sh not found" >&2
        return 1
    fi

    if [ -f "$DOTFILES_DIR/bin/dhp-utils.sh" ]; then
        # shellcheck disable=SC1090
        source "$DOTFILES_DIR/bin/dhp-utils.sh"
    fi
}

dhp_validate_temperature() {
    local value="${1:-}"
    if [[ -z "$value" || ! "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        return 1
    fi
    awk -v temp="$value" 'BEGIN { exit !(temp >= 0 && temp <= 2) }'
}

# Function to parse common flags like --stream, --verbose
# Sets global variables: USE_STREAMING, USE_VERBOSE, PARAM_TEMPERATURE
# Stores remaining non-flag arguments in REMAINING_ARGS array for caller to use
# Usage:
#   dhp_parse_flags "$@"
#   set -- "${REMAINING_ARGS[@]}"
dhp_parse_flags() {
    USE_STREAMING="${USE_STREAMING:-false}"
    USE_VERBOSE="${USE_VERBOSE:-false}"
    PARAM_TEMPERATURE="${PARAM_TEMPERATURE:-}"
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
                if [[ -z "${2:-}" || "${2:-}" == --* ]] || ! dhp_validate_temperature "$2"; then
                    echo "Error: --temperature requires a numeric value between 0.0 and 2.0, got '${2:-}'." >&2
                    return 1
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
                    REMAINING_ARGS+=("$1")
                    shift
                done
                ;;
            --*)
                echo "Error: Unknown flag: $1" >&2
                return 1
                ;;
            *)
                REMAINING_ARGS+=("$1")
                shift
                ;;
        esac
    done
}

dhp_registry_root() {
    printf '%s\n' "${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
}

dhp_registry_file() {
    local root
    root="$(dhp_registry_root)"
    printf '%s\n' "${DHP_DISPATCHER_REGISTRY:-$root/config/dhp-dispatchers.tsv}"
}

dhp_normalize_dispatcher_id() {
    local dispatcher="${1:-}"

    dispatcher="${dispatcher##*/}"
    dispatcher="${dispatcher%.sh}"
    case "$dispatcher" in
        dhp-*)
            dispatcher="${dispatcher#dhp-}"
            ;;
        aicopy)
            dispatcher="copy"
            ;;
        ai-project)
            dispatcher="project"
            ;;
        ai-chain)
            dispatcher="chain"
            ;;
    esac

    [ -n "$dispatcher" ] || return 1
    printf '%s\n' "$dispatcher"
}

dhp_registry_row() {
    local dispatcher="${1:-}"
    local registry
    local normalized

    normalized="$(dhp_normalize_dispatcher_id "$dispatcher")" || return 1
    registry="$(dhp_registry_file)"
    [ -f "$registry" ] || return 1

    awk -F '\t' -v id="$normalized" '
        NF && $1 !~ /^#/ && $1 == id {
            print
            found = 1
            exit
        }
        END { exit(found ? 0 : 1) }
    ' "$registry"
}

dhp_registry_field_index() {
    case "${1:-}" in
        id) echo 1 ;;
        script) echo 2 ;;
        mode) echo 3 ;;
        display_name) echo 4 ;;
        model_type) echo 5 ;;
        model_env) echo 6 ;;
        output_env) echo 7 ;;
        default_temperature) echo 8 ;;
        prompt_file) echo 9 ;;
        *) return 1 ;;
    esac
}

dhp_registry_field() {
    local dispatcher="${1:-}"
    local field="${2:-}"
    local row
    local index

    row="$(dhp_registry_row "$dispatcher")" || return 1
    index="$(dhp_registry_field_index "$field")" || return 1
    printf '%s\n' "$row" | awk -F '\t' -v idx="$index" '{ print $idx }'
}

dhp_registry_ids() {
    local registry
    registry="$(dhp_registry_file)"
    [ -f "$registry" ] || return 1

    awk -F '\t' 'NF && $1 !~ /^#/ { print $1 }' "$registry"
}

# Human-readable list used by UX/help paths.
dhp_available_dispatchers() {
    local ids=""
    local id=""

    while IFS= read -r id; do
        [ -n "$id" ] || continue
        if [ -z "$ids" ]; then
            ids="$id"
        else
            ids="$ids, $id"
        fi
    done < <(dhp_registry_ids)

    printf '%s\n' "$ids"
}

# Resolve dispatcher aliases to canonical script names.
# Usage: script_name=$(dhp_dispatcher_script_name "tech")
dhp_dispatcher_script_name() {
    dhp_registry_field "${1:-}" script
}

dhp_registry_prompt_path() {
    local dispatcher="${1:-}"
    local prompt_file
    local root

    prompt_file="$(dhp_registry_field "$dispatcher" prompt_file)" || return 1
    [ -n "$prompt_file" ] && [ "$prompt_file" != "-" ] || return 1
    case "$prompt_file" in
        /*)
            printf '%s\n' "$prompt_file"
            ;;
        *)
            root="$(dhp_registry_root)"
            printf '%s/%s\n' "$root" "$prompt_file"
            ;;
    esac
}

dhp_dispatch_registered() {
    local dispatcher="${1:-}"
    shift || true

    local row=""
    local id=""
    local script_name=""
    local mode=""
    local display_name=""
    local model_type=""
    local model_env=""
    local output_env=""
    local default_temperature=""
    local prompt_file=""
    local prompt_path=""
    local system_brief=""

    row="$(dhp_registry_row "$dispatcher")" || {
        echo "Error: unknown dispatcher '$dispatcher'." >&2
        return 1
    }

    IFS=$'\t' read -r id script_name mode display_name model_type model_env output_env default_temperature prompt_file <<< "$row"

    if [ "$mode" != "registry" ]; then
        echo "Error: dispatcher '$id' is handled by $script_name, not the registry-backed swarm path." >&2
        return 1
    fi

    prompt_path="$(dhp_registry_prompt_path "$id")" || {
        echo "Error: registry prompt path missing for dispatcher '$id'." >&2
        return 1
    }
    if [ ! -f "$prompt_path" ]; then
        echo "Error: registry prompt file not found: $prompt_path" >&2
        return 1
    fi

    system_brief="$(cat "$prompt_path")"
    dhp_dispatch "$display_name" "$model_type" "" "$model_env" "$output_env" "$system_brief" "$default_temperature" "$@"
}

dhp_dispatch_from_script() {
    local caller="${BASH_SOURCE[1]:-}"
    local dispatcher=""

    if [ -z "$caller" ]; then
        echo "Error: cannot determine dispatcher shim name." >&2
        return 1
    fi

    dispatcher="$(dhp_normalize_dispatcher_id "$caller")" || return 1
    dhp_dispatch_registered "$dispatcher" "$@"
}

dhp_resolve_dispatcher_command() {
    local target="${1:-}"
    local dotfiles_root="${2:-${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
    local script_name=""
    local resolved=""

    if [[ -z "$target" ]]; then
        return 1
    fi

    if script_name=$(dhp_dispatcher_script_name "$target" 2>/dev/null); then
        if [ -x "$dotfiles_root/bin/$script_name" ]; then
            printf '%s\n' "$dotfiles_root/bin/$script_name"
            return 0
        fi
    fi

    if resolved=$(command -v "$target" 2>/dev/null); then
        printf '%s\n' "$resolved"
        return 0
    fi

    if [ -x "$dotfiles_root/bin/$target" ]; then
        printf '%s\n' "$dotfiles_root/bin/$target"
        return 0
    fi

    if [ -x "$dotfiles_root/bin/$target.sh" ]; then
        printf '%s\n' "$dotfiles_root/bin/$target.sh"
        return 0
    fi

    if [ -x "$dotfiles_root/bin/dhp-$target.sh" ]; then
        printf '%s\n' "$dotfiles_root/bin/dhp-$target.sh"
        return 0
    fi

    return 1
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
            if ! "$DOTFILES_DIR/bin/dhp-memory.sh" \
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
# Usage: dhp_dispatch "SERVICE_NAME" "MODEL_TYPE" "OUTPUT_DIR_BASE(optional)" "ENV_MODEL_VAR" "ENV_OUTPUT_VAR" "SYSTEM_BRIEF" "DEFAULT_TEMP" -- "$@"
dhp_dispatch() {
    local service_name="$1"
    local model_type="${2:-DEFAULT}"
    local output_base="${3:-}"
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

    if [ ! -d "$AI_STAFF_DIR" ]; then
        echo "Warning: AI Staff HQ unavailable at $AI_STAFF_DIR." >&2
        echo "Set AI_STAFF_DIR to a valid checkout or restore $DOTFILES_DIR/ai-staff-hq before running $service_name." >&2
        return 1
    fi

    # 4. Configuration (Model & Output)
    # Primary env var is passed in (e.g., TECH_MODEL).
    local model_primary="${!env_model_var:-}"
    local default_model_env="${DEFAULT_MODEL:-}"
    local model_final=""
    
    if [ -n "$model_primary" ]; then
        model_final="$model_primary"
    elif [ -n "$default_model_env" ]; then
        model_final="$default_model_env"
    else
        model_final="$(get_model "$model_type")"
    fi
    
    # Resolve Output Directory
    local output_dir_default="$output_base"
    local output_dir_final
    if [ -z "$output_dir_default" ] && type get_output_dir >/dev/null 2>&1; then
        output_dir_default=$(get_output_dir "$model_type")
    fi
    if [ -z "$output_dir_default" ]; then
        output_dir_default="${DHP_OUTPUT_BASE:-${AI_OUTPUT_BASE:-$HOME/Documents/AI_Staff_HQ_Outputs}}/General"
    fi
    output_dir_final=$(default_output_dir "$output_dir_default" "$env_output_var")
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
    
    cmd_args+=(--parallel --max-parallel 5 --auto-approve)
    
    if [ "$USE_VERBOSE" = "true" ]; then
        cmd_args+=(--verbose)
    fi
    
    if [ "$USE_STREAMING" = "true" ]; then
        cmd_args+=(--stream)
    fi
    
    # 7. Execute safely using array expansion
    local exit_code=0
    if echo "$enhanced_brief" | "${cmd_args[@]}" | tee "$output_file"; then
        exit_code=0
    else
        exit_code=$?
    fi

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
export -f dhp_validate_temperature
export -f dhp_parse_flags
export -f dhp_registry_root
export -f dhp_registry_file
export -f dhp_normalize_dispatcher_id
export -f dhp_registry_row
export -f dhp_registry_field_index
export -f dhp_registry_field
export -f dhp_registry_ids
export -f dhp_available_dispatchers
export -f dhp_dispatcher_script_name
export -f dhp_registry_prompt_path
export -f dhp_resolve_dispatcher_command
export -f dhp_get_input
export -f slugify
export -f dhp_save_artifact
export -f dhp_dispatch
export -f dhp_dispatch_registered
export -f dhp_dispatch_from_script
