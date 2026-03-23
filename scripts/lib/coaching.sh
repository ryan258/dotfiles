#!/usr/bin/env bash
# scripts/lib/coaching.sh
# Thin facade over coach_ops.sh for workflow scripts.
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_COACHING_FACADE_LOADED:-}" ]]; then
    return 0
fi
readonly _COACHING_FACADE_LOADED=true

# Dependencies:
# - coach_ops.sh, coach_metrics.sh, coach_prompts.sh, and coach_scoring.sh
#   must already be sourced by the caller.

_coaching_require_fn() {
    local fn_name="$1"
    if ! command -v "$fn_name" >/dev/null 2>&1; then
        echo "Error: $fn_name is unavailable. Source coach_ops.sh, coach_metrics.sh, coach_prompts.sh, and coach_scoring.sh before coaching.sh." >&2
        return 1
    fi
    return 0
}

coaching_get_mode_for_date() {
    _coaching_require_fn "coach_get_mode_for_date" || return 1
    coach_get_mode_for_date "$@"
}

coaching_collect_tactical_metrics() {
    _coaching_require_fn "coach_collect_tactical_metrics" || return 1
    coach_collect_tactical_metrics "$@"
}

coaching_collect_pattern_metrics() {
    _coaching_require_fn "coach_collect_pattern_metrics" || return 1
    coach_collect_pattern_metrics "$@"
}

coaching_collect_data_quality_flags() {
    _coaching_require_fn "coach_collect_data_quality_flags" || return 1
    coach_collect_data_quality_flags "$@"
}

coaching_build_behavior_digest() {
    _coaching_require_fn "coach_build_behavior_digest" || return 1
    coach_build_behavior_digest "$@"
}

coaching_build_startday_prompt() {
    _coaching_require_fn "coach_build_startday_prompt" || return 1
    coach_build_startday_prompt "$@"
}

coaching_build_goodevening_prompt() {
    _coaching_require_fn "coach_build_goodevening_prompt" || return 1
    coach_build_goodevening_prompt "$@"
}

coaching_build_status_prompt() {
    _coaching_require_fn "coach_build_status_prompt" || return 1
    coach_build_status_prompt "$@"
}

coaching_strategy_with_retry() {
    _coaching_require_fn "coach_strategy_with_retry" || return 1
    coach_strategy_with_retry "$@"
}

coaching_strategy_dispatcher_name() {
    _coaching_require_fn "coach_strategy_dispatcher_name" || return 1
    coach_strategy_dispatcher_name "$@"
}

coaching_startday_fallback_output() {
    _coaching_require_fn "coach_startday_fallback_output" || return 1
    coach_startday_fallback_output "$@"
}

coaching_goodevening_fallback_output() {
    _coaching_require_fn "coach_goodevening_fallback_output" || return 1
    coach_goodevening_fallback_output "$@"
}

coaching_status_fallback_output() {
    _coaching_require_fn "coach_status_fallback_output" || return 1
    coach_status_fallback_output "$@"
}

coaching_append_log() {
    _coaching_require_fn "coach_append_log" || return 1
    coach_append_log "$@"
}

# Core execution pipeline for the personalized AI coach.
# If the AI returns output, pass it through untouched. Only synthesize
# deterministic fallback text when the dispatcher times out or fails.
# Parameters:
#   $1 - prompt: The constructed system + user prompt for the dispatcher
#   $2 - temperature: The temperature for the LLM call
#   $3 - focus_context: Declared daily focus used for coach context
#   $4 - mode: Current coach mode (LOCKED, FLOW, etc)
#   $5 - git_commits: Recent GitHub activity/evidence
#   $6 - behavior_digest: The generated user behavior + health metrics digest
#   $7 - type: The type of flow making the call (startday, goodevening, status)
#   $8 - project_context: (Optional) Current project status checks (used by status.sh)
#   $9 - context_scope: (Optional) 'repo' or 'global' scope flag
#  $10 - current_dir: (Optional) Active directory, specifically evaluated for repo-scoped status checks
coaching_generate_response() {
    local prompt="$1"
    local temperature="$2"
    local focus_context="$3"
    local mode="$4"
    local git_commits="$5"
    local behavior_digest="$6"
    local type="$7"
    local project_context="${8:-}"
    local context_scope="${9:-global}"
    local current_dir="${10:-}"

    local result=""
    local reason=""
    local exit_code=0
    
    local dispatcher=""
    if command -v coaching_strategy_dispatcher_name >/dev/null 2>&1; then
        dispatcher=$(coaching_strategy_dispatcher_name 2>/dev/null || true)
    fi

    if [ -n "$dispatcher" ]; then
        if command -v coaching_strategy_with_retry >/dev/null 2>&1; then
            set +e
            result=$(coaching_strategy_with_retry "$prompt" "$temperature" "${AI_COACH_REQUEST_TIMEOUT_SECONDS:-35}" "${AI_COACH_RETRY_TIMEOUT_SECONDS:-90}")
            exit_code=$?
            set -e
            if [ "$exit_code" -eq 0 ]; then
                reason=""
            elif [ "$exit_code" -eq 124 ]; then
                reason="timeout"
            else
                reason="error"
            fi
        else
            set +e
            result=$(printf '%s' "$prompt" | "$dispatcher" --temperature "$temperature")
            exit_code=$?
            set -e
            if [ "$exit_code" -eq 0 ]; then
                reason=""
            else
                reason="error"
            fi
        fi
    else
        reason="dispatcher-missing"
    fi

    if [ -z "$result" ]; then
        reason="${reason:-unavailable}"
        if [ "$type" = "startday" ] && command -v coaching_startday_fallback_output >/dev/null 2>&1; then
            result=$(coaching_startday_fallback_output "${focus_context:-"(no focus set)"}" "$mode" "$reason" "$behavior_digest" "${git_commits}")
        elif [ "$type" = "goodevening" ] && command -v coaching_goodevening_fallback_output >/dev/null 2>&1; then
            result=$(coaching_goodevening_fallback_output "${focus_context:-"(no focus set)"}" "$mode" "$reason" "$behavior_digest" "${git_commits}")
        elif [ "$type" = "status" ] && command -v coaching_status_fallback_output >/dev/null 2>&1; then
            result=$(coaching_status_fallback_output "${focus_context:-"(no focus set)"}" "$mode" "$reason" "$behavior_digest" "$git_commits" "$current_dir" "$project_context" "$context_scope")
        else
            result="Unable to generate AI output at this time."
        fi
    fi

    printf '%s' "$result"
}
