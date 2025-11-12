#!/bin/bash

# dhp-lib.sh: Shared Library for AI Dispatchers
# Provides error handling and streaming support functions
# Source this file in dispatcher scripts: source "$DOTFILES_DIR/bin/dhp-lib.sh"

# --- Private Helper Functions ---

# _build_json_payload: Constructs the JSON payload for the API call.
_build_json_payload() {
    local model="$1"
    local prompt="$2"
    local stream_flag="$3"
    local temperature="${DHP_TEMPERATURE:-${DHP_TEMPERATURE_DEFAULT:-null}}"
    local max_tokens="${DHP_MAX_TOKENS:-${DHP_MAX_TOKENS_DEFAULT:-null}}"

    jq -n \
        --arg model "$model" \
        --arg prompt "$prompt" \
        --argjson stream "$stream_flag" \
        --argjson temperature "$temperature" \
        --argjson max_tokens "$max_tokens" \
        '{
            model: $model,
            messages: [{role: "user", content: $prompt}],
            stream: $stream
        } |
        (if $temperature != null then . + {temperature: $temperature} else . end) |
        (if $max_tokens != null then . + {max_tokens: $max_tokens} else . end)'
}

# _handle_api_error: Parses and prints a standardized error message.
_handle_api_error() {
    local response="$1"
    local error_msg
    error_msg=$(echo "$response" | jq -r '.error.message // .error // "Unknown error"')
    printf "Error: API returned an error: %s\n" "$error_msg" >&2
    return 1
}

# --- Public API Functions ---

# call_openrouter_sync: Makes a synchronous API call and returns the complete response.
# Usage: call_openrouter_sync <model> <prompt>
call_openrouter_sync() {
    local model="$1"
    local prompt="$2"
    local json_payload
    json_payload=$(_build_json_payload "$model" "$prompt" "false")

    local response
    response=$(curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        _handle_api_error "$response"
        return 1
    fi

    if ! echo "$response" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
        printf "Error: Unexpected API response format.\nResponse: %s\n" "$response" >&2
        return 1
    fi

    echo "$response" | jq -r '.choices[0].message.content'
}

# call_openrouter_stream: Makes a streaming API call and prints content deltas.
# Usage: call_openrouter_stream <model> <prompt>
call_openrouter_stream() {
    local model="$1"
    local prompt="$2"
    local json_payload
    json_payload=$(_build_json_payload "$model" "$prompt" "true")

    curl -s -N -X POST "https://openrouter.ai/api/v1/chat/completions" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$json_payload" | while IFS= read -r line; do
            [ -z "$line" ] && continue
            [[ "$line" == "data: [DONE]" ]] && break

            if [[ "$line" == data:* ]]; then
                local json_data="${line#data: }"
                if echo "$json_data" | jq -e '.error' > /dev/null 2>&1; then
                    _handle_api_error "$json_data"
                    return 1 # Note: This return may not exit the parent script in a pipeline
                fi

                local content
                content=$(echo "$json_data" | jq -r '.choices[0].delta.content // empty')
                if [ -n "$content" ] && [ "$content" != "null" ]; then
                    printf "%s" "$content"
                fi
            fi
        done
    echo # Ensure a final newline
}

# --- Call Router ---
# call_openrouter: A wrapper that decides whether to stream or not.
# This maintains backward compatibility with the old function signature.
# Usage: call_openrouter <model> <prompt> [--stream]
call_openrouter() {
    local model="$1"
    local prompt="$2"
    local stream_flag="$3"

    if [ "$stream_flag" = "--stream" ]; then
        call_openrouter_stream "$model" "$prompt"
    else
        call_openrouter_sync "$model" "$prompt"
    fi
}

# Export functions if sourced
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    export -f call_openrouter call_openrouter_sync call_openrouter_stream
fi
