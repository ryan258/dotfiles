#!/usr/bin/env bash
# scripts/lib/coaching.sh
# Stable coaching namespace for workflow scripts.
# This facade is intentionally thin: workflow entry points call `coaching_*`,
# while the implementation lives in `coach_*` libraries underneath.
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_COACHING_FACADE_LOADED:-}" ]]; then
    return 0
fi
readonly _COACHING_FACADE_LOADED=true

# Dependencies:
# - coach_ops.sh, coach_metrics.sh, coach_brief.sh, coach_prompts.sh, and
#   coach_scoring.sh must already be sourced by the caller.
# Keep these wrappers in place so startday/status/goodevening have one stable
# namespace even when the underlying coach libraries evolve.

coaching_get_mode_for_date() {
    coach_get_mode_for_date "$@"
}

coaching_collect_tactical_metrics() {
    coach_collect_tactical_metrics "$@"
}

coaching_collect_pattern_metrics() {
    coach_collect_pattern_metrics "$@"
}

coaching_collect_data_quality_flags() {
    coach_collect_data_quality_flags "$@"
}

coaching_build_behavior_digest() {
    coach_build_behavior_digest "$@"
}

coaching_render_brief_from_digest() {
    coach_brief_render_from_digest "$@"
}

coaching_render_brief() {
    coach_brief_render "$@"
}

coaching_build_prebrief_questions() {
    coach_build_prebrief_questions "$@"
}

coaching_collect_prebrief_context() {
    coach_collect_prebrief_context "$@"
}

coaching_build_framing_template() {
    coach_build_framing_template "$@"
}

coaching_build_framing_prompt() {
    coach_build_framing_prompt "$@"
}

coaching_strategy_with_retry() {
    coach_strategy_with_retry "$@"
}

coaching_strategy_dispatcher_name() {
    coach_strategy_dispatcher_name "$@"
}

coaching_append_log() {
    coach_append_log "$@"
}

# Core execution pipeline for the personalized AI coach.
# Phase 4 architecture: callers build a framing prompt that wraps the
# deterministic brief. The AI's output passes through untouched. On dispatcher
# failure, return a brief-aware message so the deterministic brief shown above
# still carries the facts the user needs.
#
# Parameters:
#   $1 - prompt: The framing prompt (template + deterministic brief)
#   $2 - temperature: The temperature for the LLM call
#   $3 - focus_context: Declared daily focus (kept for caller compatibility; unused here)
#   $4 - mode: Current coach mode (kept for caller compatibility; unused here)
#   $5 - git_commits: Recent GitHub activity (kept for caller compatibility; unused here)
#   $6 - behavior_digest: Behavior digest (kept for caller compatibility; unused here)
#   $7 - type: The type of flow making the call (startday, goodevening, status)
#   $8 - project_context: (Optional, kept for caller compatibility; unused here)
#   $9 - context_scope: (Optional, kept for caller compatibility; unused here)
#  $10 - current_dir: (Optional, kept for caller compatibility; unused here)
coaching_generate_response() {
    local prompt="$1"
    local temperature="$2"
    local type="${7:-coach}"

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
            if [ "$exit_code" -eq 124 ]; then
                reason="timeout"
            elif [ "$exit_code" -ne 0 ]; then
                reason="error"
            fi
        else
            set +e
            result=$(printf '%s' "$prompt" | "$dispatcher" --temperature "$temperature")
            exit_code=$?
            set -e
            if [ "$exit_code" -ne 0 ]; then
                reason="error"
            fi
        fi
    else
        reason="dispatcher-missing"
    fi

    if [ -z "$result" ]; then
        local label="$type"
        case "$type" in
            startday) label="briefing" ;;
            goodevening) label="reflection" ;;
            status) label="coaching" ;;
        esac
        if [ -n "$reason" ]; then
            result="AI ${label} was ${reason}; deterministic coach brief is shown above."
        else
            result="AI ${label} was unavailable; deterministic coach brief is shown above."
        fi
    fi

    printf '%s' "$result"
}
