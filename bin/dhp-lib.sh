#!/bin/bash

# dhp-lib.sh: Shared Library for AI Dispatchers
# Provides error handling and streaming support functions
# Source this file in dispatcher scripts: source "$DOTFILES_DIR/bin/dhp-lib.sh"

# Call OpenRouter API with error handling and optional streaming
# Usage: call_openrouter <model> <prompt> [--stream]
# Returns: 0 on success, 1 on error
call_openrouter() {
    local model="$1"
    local prompt="$2"
    local use_streaming=false
    local temperature="${DHP_TEMPERATURE:-${DHP_TEMPERATURE_DEFAULT:-}}"
    local max_tokens="${DHP_MAX_TOKENS:-${DHP_MAX_TOKENS_DEFAULT:-}}"

    # Check for --stream flag
    if [ "$3" = "--stream" ]; then
        use_streaming=true
    fi

    # Build JSON payload
    if [ "$use_streaming" = true ]; then
        JSON_PAYLOAD=$(jq -n \
            --arg model "$model" \
            --arg prompt "$prompt" \
            --argjson temperature "${temperature:-null}" \
            --argjson max_tokens "${max_tokens:-null}" \
            '{model: $model, messages: [{role: "user", content: $prompt}], stream: true} as $base | $base + (if $temperature? then {temperature: $temperature} else {} end) + (if $max_tokens? then {max_tokens: $max_tokens} else {} end)')
    else
        JSON_PAYLOAD=$(jq -n \
            --arg model "$model" \
            --arg prompt "$prompt" \
            --argjson temperature "${temperature:-null}" \
            --argjson max_tokens "${max_tokens:-null}" \
            '{model: $model, messages: [{role: "user", content: $prompt}]} as $base | $base + (if $temperature? then {temperature: $temperature} else {} end) + (if $max_tokens? then {max_tokens: $max_tokens} else {} end)')
    fi

    # Make API call
    if [ "$use_streaming" = true ]; then
        # Streaming mode: process Server-Sent Events (SSE)
        curl -s -N -X POST "https://openrouter.ai/api/v1/chat/completions" \
            -H "Authorization: Bearer $OPENROUTER_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$JSON_PAYLOAD" | while IFS= read -r line; do

            # Skip empty lines
            [ -z "$line" ] && continue

            # Check for [DONE] signal
            if [[ "$line" == "data: [DONE]" ]]; then
                break
            fi

            # Extract data from SSE format
            if [[ "$line" == data:* ]]; then
                json_data="${line#data: }"

                # Check for error in streaming response
                if echo "$json_data" | jq -e '.error' > /dev/null 2>&1; then
                    error_msg=$(echo "$json_data" | jq -r '.error.message // .error')
                    echo "Error: API returned an error: $error_msg" >&2
                    return 1
                fi

                # Extract and print content delta
                content=$(echo "$json_data" | jq -r '.choices[0].delta.content // empty' 2>/dev/null)
                if [ -n "$content" ] && [ "$content" != "null" ]; then
                    printf "%s" "$content"
                fi
            fi
        done

        # Add newline at end of stream
        echo
        return 0
    else
        # Non-streaming mode: get complete response
        response=$(curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
            -H "Authorization: Bearer $OPENROUTER_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$JSON_PAYLOAD")

        # Check for error in response
        if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
            error_msg=$(echo "$response" | jq -r '.error.message // .error')
            echo "Error: API returned an error: $error_msg" >&2
            return 1
        fi

        # Check if response has expected structure
        if ! echo "$response" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
            echo "Error: Unexpected API response format" >&2
            echo "Response: $response" >&2
            return 1
        fi

        # Extract and print content
        echo "$response" | jq -r '.choices[0].message.content'
        return 0
    fi
}

# Export function if sourced
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    export -f call_openrouter
fi
