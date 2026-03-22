#!/usr/bin/env bash
set -euo pipefail

# dhp-coach.sh - Lightweight direct coach dispatcher
# Single-call OpenRouter path for fast daily coaching without swarm orchestration.

source "$(dirname "$0")/dhp-shared.sh"

dhp_setup_env
dhp_parse_flags "$@"
if [ ${#REMAINING_ARGS[@]} -gt 0 ]; then
    set -- "${REMAINING_ARGS[@]}"
else
    set --
fi

validate_dependencies curl jq
ensure_api_key OPENROUTER_API_KEY

if [ -z "${PIPED_CONTENT:-}" ]; then
    dhp_get_input "$@"
fi

if [ -z "${PIPED_CONTENT:-}" ]; then
    echo "Usage: echo \"prompt\" | $(basename "$0") [options]" >&2
    echo "   or: $(basename "$0") \"prompt\" [options]" >&2
    exit 1
fi

export PARAM_TEMPERATURE="${PARAM_TEMPERATURE:-${AI_BRIEFING_TEMPERATURE:-0.25}}"

COACH_SYSTEM_BRIEF="You are a fast, grounded daily coaching specialist.

Rules:
- Answer in one pass with no swarm planning or task decomposition.
- Follow the schema requested by the prompt exactly.
- Reuse the exact section headings requested by the prompt.
- Ground every action in the evidence supplied by the prompt.
- Do not invent task completions, publish events, commit counts, or dates that are not explicitly present.
- Do not invent page names, homepage sections, paragraph states, file paths, or draft status unless explicitly present.
- If evidence is thin, say so plainly instead of inventing work.
- Keep the response concise, operational, and specific.
- Do not mention internal tooling, dispatchers, or model selection."

dhp_dispatch \
    "Coach" \
    "strategy" \
    "$HOME/Documents/AI_Staff_HQ_Outputs/Strategy/Coach" \
    "COACH_MODEL" \
    "DHP_COACH_OUTPUT_DIR" \
    "$COACH_SYSTEM_BRIEF" \
    "$PARAM_TEMPERATURE" \
    "$@"
