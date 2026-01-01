#!/bin/bash

# dhp-lib.sh: Shared Library for AI Dispatchers
# Provides error handling and streaming support functions
# Source this file in dispatcher scripts: source "$DOTFILES_DIR/bin/dhp-lib.sh"

# --- Configuration ---
DISPATCHER_USAGE_LOG="$HOME/.config/dotfiles-data/dispatcher_usage.log"

# --- Private Helper Functions ---

# _api_cooldown: Enforces a delay between API calls.
_api_cooldown() {
    local cooldown="${API_COOLDOWN_SECONDS:-0}"
    if [ "$cooldown" -gt 0 ]; then
        sleep "$cooldown"
    fi
}

# _log_api_call: Logs details of an API call.
# Usage: _log_api_call <dispatcher_name> <model> [prompt_tokens] [completion_tokens]
_log_api_call() {
    local dispatcher_name="${1:-unknown}"
    local model="${2:-unknown}"
    local prompt_tokens="${3:-0}"
    local completion_tokens="${4:-0}"
    
    # Simple cost estimation (placeholder rates per 1M tokens)
    # Default to $0.50 input / $1.50 output if unknown
    local rate_input=0.50
    local rate_output=1.50
    
    # Adjust rates for known free models
    if [[ "$model" == *":free" ]]; then
        rate_input=0
        rate_output=0
    fi

    # Calculate cost: (tokens / 1000000) * rate
    local cost_input
    cost_input=$(awk "BEGIN {printf \"%.6f\", ($prompt_tokens / 1000000) * $rate_input}")
    local cost_output
    cost_output=$(awk "BEGIN {printf \"%.6f\", ($completion_tokens / 1000000) * $rate_output}")
    local total_cost
    total_cost=$(awk "BEGIN {printf \"%.6f\", $cost_input + $cost_output}")

    printf "[%s] DISPATCHER: %s, MODEL: %s, PROMPT_TOKENS: %s, COMPLETION_TOKENS: %s, EST_COST: $%s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$dispatcher_name" "$model" "$prompt_tokens" "$completion_tokens" "$total_cost" >> "$DISPATCHER_USAGE_LOG"
}

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
# Usage: call_openrouter_sync <model> <prompt> <dispatcher_name>
call_openrouter_sync() {
    local model="$1"
    local prompt="$2"
    local dispatcher_name="${3:-unknown}"

    local json_payload
    json_payload=$(_build_json_payload "$model" "$prompt" "false")

    _api_cooldown # Enforce cooldown before API call

    local response
    response=$(curl -s --max-time 300 -X POST "https://openrouter.ai/api/v1/chat/completions" \
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

    local prompt_tokens; prompt_tokens=$(echo "$response" | jq -r '.usage.prompt_tokens // 0')
    local completion_tokens; completion_tokens=$(echo "$response" | jq -r '.usage.completion_tokens // 0')
    _log_api_call "$dispatcher_name" "$model" "$prompt_tokens" "$completion_tokens"

    echo "$response" | jq -r '.choices[0].message.content'
}

# call_openrouter_stream: Makes a streaming API call and prints content deltas.
# Usage: call_openrouter_stream <model> <prompt> <dispatcher_name>
call_openrouter_stream() {
    local model="$1"
    local prompt="$2"
    local dispatcher_name="${3:-unknown}"
    # For streaming, tokens are not easily available until the stream ends.
    # A more advanced implementation would parse stream events for token usage.
    _log_api_call "$dispatcher_name" "$model" "0" "0" # Log with 0 tokens for now

    local json_payload
    json_payload=$(_build_json_payload "$model" "$prompt" "true")

    _api_cooldown # Enforce cooldown before API call

    local stream_status=0
    local curl_status=0
    local fifo
    fifo=$(mktemp -u)
    mkfifo "$fifo"

    curl -s -N --max-time 300 -X POST "https://openrouter.ai/api/v1/chat/completions" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$json_payload" > "$fifo" &
    local curl_pid=$!

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        [[ "$line" == "data: [DONE]" ]] && break

        if [[ "$line" == data:* ]]; then
            local json_data="${line#data: }"
            if echo "$json_data" | jq -e '.error' > /dev/null 2>&1; then
                _handle_api_error "$json_data"
                stream_status=1
                break
            fi

            local content
            content=$(echo "$json_data" | jq -r '.choices[0].delta.content // empty')
            if [ -n "$content" ] && [ "$content" != "null" ]; then
                printf "%s" "$content"
            fi
        fi
    done < "$fifo"

    if [ "$stream_status" -ne 0 ]; then
        kill "$curl_pid" 2>/dev/null || true
    fi

    wait "$curl_pid"
    curl_status=$?
    rm -f "$fifo"

    if [ "$stream_status" -ne 0 ]; then
        return "$stream_status"
    fi
    if [ "$curl_status" -ne 0 ]; then
        return "$curl_status"
    fi

    echo # Ensure a final newline
}

# --- Call Router ---
# call_openrouter: A wrapper that decides whether to stream or not.
# This maintains backward compatibility with the old function signature.
# Usage: call_openrouter <model> <prompt> [--stream] <dispatcher_name>
call_openrouter() {
    local model="$1"
    local prompt="$2"
    local stream_flag="$3"
    local dispatcher_name="${4:-unknown}" # Pass dispatcher name through

    if [ "$stream_flag" = "--stream" ]; then
        call_openrouter_stream "$model" "$prompt" "$dispatcher_name"
    else
        call_openrouter_sync "$model" "$prompt" "$dispatcher_name"
    fi
}

# Export functions if sourced
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    export -f call_openrouter call_openrouter_sync call_openrouter_stream _log_api_call
fi
