#!/usr/bin/env bash
# scripts/lib/coach_scoring.sh
# AI dispatch, response grounding, mode management, and logging for coaching.
# NOTE: SOURCED file. Do NOT use set -euo pipefail.
#
# Dependencies:
# - coach_metrics.sh must be sourced first (provides _coach_secure_tmpfile, _coach_escape_field).
# - COACH_MODE_FILE and COACH_LOG_FILE from config.sh.

if [[ -n "${_COACH_SCORING_LOADED:-}" ]]; then
    return 0
fi
readonly _COACH_SCORING_LOADED=true

coach_call_with_timeout() {
    local prompt="$1"
    local timeout_seconds="${2:-${AI_COACH_REQUEST_TIMEOUT_SECONDS:-35}}"
    shift 2

    if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$timeout_seconds" -lt 1 ]]; then
        timeout_seconds=35
    fi
    if [[ "$#" -eq 0 ]]; then
        return 2
    fi

    if command -v python3 >/dev/null 2>&1; then
        local python_output=""
        local python_status=0
        python_output=$(python3 - "$prompt" "$timeout_seconds" "$@" <<'PY'
import subprocess
import sys

prompt = sys.argv[1]
timeout_seconds = int(sys.argv[2])
command = sys.argv[3:]

try:
    result = subprocess.run(
        command,
        input=prompt,
        text=True,
        capture_output=True,
        timeout=timeout_seconds,
    )
except subprocess.TimeoutExpired as exc:
    if exc.stdout:
        sys.stdout.write(exc.stdout)
    sys.stderr.write(
        f"coach_call_with_timeout: timed out after {timeout_seconds} seconds\n"
    )
    sys.exit(124)

if result.stdout:
    sys.stdout.write(result.stdout)

if result.returncode != 0:
    if result.stderr:
        sys.stderr.write(result.stderr)
    sys.exit(result.returncode)
PY
)
        python_status=$?
        printf '%s' "$python_output"
        return "$python_status"
    fi

    local prompt_file=""
    local output_file=""
    local error_file=""
    local child_pid=0
    local elapsed=0
    local child_status=0

    prompt_file=$(_coach_secure_tmpfile "coach_prompt") || return 1
    output_file=$(_coach_secure_tmpfile "coach_out") || {
        rm -f "$prompt_file"
        return 1
    }
    error_file=$(_coach_secure_tmpfile "coach_err") || {
        rm -f "$prompt_file" "$output_file"
        return 1
    }

    printf '%s' "$prompt" > "$prompt_file"
    "$@" < "$prompt_file" > "$output_file" 2> "$error_file" &
    child_pid=$!

    while kill -0 "$child_pid" 2>/dev/null; do
        if [[ "$elapsed" -ge "$timeout_seconds" ]]; then
            kill "$child_pid" 2>/dev/null || true
            sleep 1
            kill -9 "$child_pid" 2>/dev/null || true
            wait "$child_pid" 2>/dev/null || true
            cat "$output_file"
            rm -f "$prompt_file" "$output_file" "$error_file"
            return 124
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    wait "$child_pid" || child_status=$?
    cat "$output_file"
    if [[ "$child_status" -ne 0 && -s "$error_file" ]]; then
        cat "$error_file" >&2
    fi

    rm -f "$prompt_file" "$output_file" "$error_file"
    return "$child_status"
}

coach_strategy_with_timeout() {
    local prompt="$1"
    local temperature="${2:-0.25}"
    local timeout_seconds="${3:-${AI_COACH_REQUEST_TIMEOUT_SECONDS:-35}}"

    coach_call_with_timeout "$prompt" "$timeout_seconds" dhp-strategy.sh --temperature "$temperature"
}

coach_strategy_with_retry() {
    local prompt="$1"
    local temperature="${2:-0.25}"
    local timeout_seconds="${3:-${AI_COACH_REQUEST_TIMEOUT_SECONDS:-35}}"
    local retry_timeout_seconds="${4:-${AI_COACH_RETRY_TIMEOUT_SECONDS:-90}}"
    local retry_enabled="${AI_COACH_RETRY_ON_TIMEOUT:-true}"

    local first_status=0
    local second_status=0
    local first_output=""
    local second_output=""

    if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$timeout_seconds" -lt 1 ]]; then
        timeout_seconds=35
    fi
    if ! [[ "$retry_timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$retry_timeout_seconds" -lt 1 ]]; then
        retry_timeout_seconds=90
    fi

    first_output=$(coach_strategy_with_timeout "$prompt" "$temperature" "$timeout_seconds")
    first_status=$?
    if [[ "$first_status" -eq 0 ]]; then
        printf '%s' "$first_output"
        return 0
    fi

    if [[ "$first_status" -ne 124 ]]; then
        return "$first_status"
    fi
    if [[ "$retry_enabled" != "true" ]]; then
        return "$first_status"
    fi
    if [[ "$retry_timeout_seconds" -le "$timeout_seconds" ]]; then
        return "$first_status"
    fi

    second_output=$(coach_strategy_with_timeout "$prompt" "$temperature" "$retry_timeout_seconds")
    second_status=$?
    if [[ "$second_status" -eq 0 ]]; then
        printf '%s' "$second_output"
        return 0
    fi
    return "$second_status"
}

_coach_line_has_context_overlap() {
    local line="$1"
    local context="$2"
    local token=""

    while IFS= read -r token; do
        [[ -z "$token" ]] && continue
        case "$token" in
            a|an|the|and|or|to|of|in|on|at|with|from|for|that|this|it|is|are|be|as|by|if|then|after|before|into|your|you|today|tomorrow|first|second|third|one|two|three|task|tasks|step|steps|done|condition|minute|minutes|block)
                continue
                ;;
        esac
        [[ "${#token}" -lt 4 ]] && continue
        if [[ "$context" == *"$token"* ]]; then
            return 0
        fi
    done < <(printf '%s' "$line" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n')

    return 1
}

_coach_line_has_ungrounded_scope_expansion() {
    local line="$1"
    local context="$2"
    local risky=""

    for risky in folder endpoint repository repo clone api manifest module database server scaffold microservice; do
        if [[ "$line" == *"$risky"* ]] && [[ "$context" != *"$risky"* ]]; then
            return 0
        fi
    done
    return 1
}

coach_startday_response_is_grounded() {
    local response="$1"
    local focus="$2"
    local tasks="$3"
    local context=""
    local do_next_lines=""
    local first_line=""
    local line=""
    local count=0

    context=$(printf '%s\n%s\n' "$focus" "$tasks" | tr '[:upper:]' '[:lower:]')
    do_next_lines=$(printf '%s\n' "$response" | awk '
        BEGIN { in_do_next = 0 }
        /^Do Next \(ordered 1-3\):[[:space:]]*$/ { in_do_next = 1; next }
        in_do_next && /^[[:space:]]*[1-3]\.[[:space:]]+/ { print; next }
        in_do_next && /^[[:space:]]*[A-Za-z][^:]*:[[:space:]]*$/ { in_do_next = 0 }
    ')

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        count=$((count + 1))
        line=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*[1-3]\.[[:space:]]+//')
        line=$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')
        if _coach_line_has_ungrounded_scope_expansion "$line" "$context"; then
            return 1
        fi
        if [[ "$count" -eq 1 ]]; then
            first_line="$line"
        fi
    done <<< "$do_next_lines"

    if [[ "$count" -lt 3 ]]; then
        return 1
    fi
    if ! _coach_line_has_context_overlap "$first_line" "$context"; then
        return 1
    fi
    return 0
}

coach_get_mode_for_date() {
    local target_date="$1"
    local interactive="${2:-false}"
    local mode_file="$COACH_MODE_FILE"
    local mode=""
    local source_tag=""
    local mode_dir=""

    if command -v validate_path >/dev/null 2>&1; then
        local validated_mode_file=""
        validated_mode_file=$(validate_path "$mode_file" 2>/dev/null) || return 1
        mode_file="$validated_mode_file"
    fi

    mode_dir=$(dirname "$mode_file")
    mkdir -p "$mode_dir"
    touch "$mode_file" 2>/dev/null || return 1

    mode=$(awk -F'|' -v day="$target_date" '$1 == day && ($2 == "LOCKED" || $2 == "OVERRIDE") {m=$2} END {print m}' "$mode_file")
    if [[ -n "$mode" ]]; then
        echo "$mode"
        return 0
    fi

    local default_mode="${AI_COACH_MODE_DEFAULT:-LOCKED}"
    default_mode=$(printf '%s' "$default_mode" | tr '[:lower:]' '[:upper:]')
    if [[ "$default_mode" != "LOCKED" && "$default_mode" != "OVERRIDE" && "$default_mode" != "RECOVERY" ]]; then
        default_mode="LOCKED"
    fi

    mode="$default_mode"
    source_tag="default"

    if [[ "$interactive" == "true" && -r /dev/tty ]]; then
        local user_input=""
        printf "🧭 Coaching mode: [L]ocked (default), [O]verride (1 exploration), [R]ecovery? [L/o/r]: " > /dev/tty
        if read -r -t 20 user_input < /dev/tty; then
            if [[ "$user_input" =~ ^[oO]$ ]]; then
                mode="OVERRIDE"
            elif [[ "$user_input" =~ ^[rR]$ ]]; then
                mode="RECOVERY"
            else
                mode="LOCKED"
            fi
            source_tag="prompt"
        else
            mode="$default_mode"
            source_tag="prompt-timeout"
        fi
        printf "\n" > /dev/tty
    elif [[ "$interactive" == "true" ]]; then
        source_tag="non-tty-default"
    fi

    printf '%s|%s|%s\n' "$target_date" "$mode" "$source_tag" >> "$mode_file"
    echo "$mode"
}

coach_append_log() {
    local log_type="$1"
    local date_value="$2"
    local mode="$3"
    local focus="$4"
    local metrics="$5"
    local output="$6"

    if [[ "${AI_COACH_LOG_ENABLED:-true}" != "true" ]]; then
        return 0
    fi

    local log_file="$COACH_LOG_FILE"
    local ts
    local log_dir
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    if command -v validate_path >/dev/null 2>&1; then
        local validated_log_file=""
        validated_log_file=$(validate_path "$log_file" 2>/dev/null) || return 1
        log_file="$validated_log_file"
    fi

    log_dir=$(dirname "$log_file")
    mkdir -p "$log_dir"
    touch "$log_file" 2>/dev/null || return 1
    chmod 600 "$log_file" 2>/dev/null || true

    printf '%s|%s|%s|%s|%s|%s|%s\n' \
        "$(_coach_escape_field "$log_type")" \
        "$(_coach_escape_field "$ts")" \
        "$(_coach_escape_field "$date_value")" \
        "$(_coach_escape_field "$mode")" \
        "$(_coach_escape_field "$focus")" \
        "$(_coach_escape_field "$metrics")" \
        "$(_coach_escape_field "$output")" >> "$log_file"
}
