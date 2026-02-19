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

coaching_strategy_with_retry() {
    _coaching_require_fn "coach_strategy_with_retry" || return 1
    coach_strategy_with_retry "$@"
}

coaching_startday_response_is_grounded() {
    _coaching_require_fn "coach_startday_response_is_grounded" || return 1
    coach_startday_response_is_grounded "$@"
}

coaching_startday_fallback_output() {
    _coaching_require_fn "coach_startday_fallback_output" || return 1
    coach_startday_fallback_output "$@"
}

coaching_goodevening_fallback_output() {
    _coaching_require_fn "coach_goodevening_fallback_output" || return 1
    coach_goodevening_fallback_output "$@"
}

coaching_append_log() {
    _coaching_require_fn "coach_append_log" || return 1
    coach_append_log "$@"
}
