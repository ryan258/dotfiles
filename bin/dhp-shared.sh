#!/bin/bash

# dhp-shared.sh: Shared library for DHP dispatcher scripts
# This script provides common setup, flag parsing, and input handling functions.

# Function to set up the environment for DHP scripts
# Sources .env, dhp-lib.sh, and dhp-utils.sh
dhp_setup_env() {
    DOTFILES_DIR="$HOME/dotfiles"
    AI_STAFF_DIR="$DOTFILES_DIR/ai-staff-hq"

    # Source environment variables
    if [ -f "$DOTFILES_DIR/.env" ]; then
        source "$DOTFILES_DIR/.env"
    fi

    # Check for API key
    if [ -z "${OPENROUTER_API_KEY:-}" ]; then
        echo "Error: OPENROUTER_API_KEY is not set. Please add it to your .env file." >&2
        exit 1
    fi

    # Source shared libraries
    if [ -f "$DOTFILES_DIR/bin/dhp-lib.sh" ]; then
        source "$DOTFILES_DIR/bin/dhp-lib.sh"
    else
        echo "Error: Shared library dhp-lib.sh not found" >&2
        exit 1
    fi

    if [ -f "$DOTFILES_DIR/bin/dhp-utils.sh" ]; then
        source "$DOTFILES_DIR/bin/dhp-utils.sh"
    fi
}

# Function to parse common flags like --stream
# Sets a global variable USE_STREAMING
# It removes the parsed flags from the arguments list.
dhp_parse_flags() {
    USE_STREAMING=false
    PARAM_TEMPERATURE=""
    PARAM_MAX_TOKENS=""
    local temp_args=()
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
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
            *)
                temp_args+=("$1")
                shift
                ;;
        esac
    done
    # Restore non-flag arguments
    set -- "${temp_args[@]}"
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
            exit 1
        fi

        # Check for maximum length (e.g., 50KB)
        MAX_INPUT_BYTES=5242880 # 5MB
        INPUT_BYTES=$(echo -n "$PIPED_CONTENT" | wc -c)
        if [ "$INPUT_BYTES" -gt "$MAX_INPUT_BYTES" ]; then
            echo "Error: Input exceeds maximum allowed size of $((MAX_INPUT_BYTES / 1024 / 1024))MB." >&2
            exit 1
        fi
    fi
}
