#!/usr/bin/env bash
# scripts/lib/coach_prompts.sh
# AI framing prompt construction for deterministic coach briefs.
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_COACH_PROMPTS_LOADED:-}" ]]; then
    return 0
fi
readonly _COACH_PROMPTS_LOADED=true

# coach_build_framing_template - Build the AI framing template (no facts).
#
# Returns short instructions that ask the AI to layer a calm framing sentence
# and one next-move recommendation on top of the deterministic brief that the
# caller will append. The template itself must never contain numbers, dates,
# bullets, or repo names. Those live in the deterministic brief.
#
# Inputs (positional):
#   1: flow_type - "startday" | "status" | "goodevening" (default: "status")
coach_build_framing_template() {
    local flow_type="${1:-status}"
    local intent_line=""

    case "$flow_type" in
        startday)
            intent_line="Give one short sentence of framing for today, then one short recommended next move."
            ;;
        goodevening)
            intent_line="Give one short sentence of framing for what closed today, then one short recommended setup for tomorrow."
            ;;
        *)
            intent_line="Give one short sentence of framing for right now, then one short recommended next move."
            ;;
    esac

    cat <<EOF
You are a calm coach summarizing the day's deterministic facts. The brief below is ground truth.

$intent_line

Stay grounded in the brief and do not invent unobserved work. Stay brief; no long menus unless the brief explicitly shows ambiguity. If the brief flags low energy or high fog, lower the demand and pace the next move.
EOF
}

# coach_build_framing_prompt - Build the full framing prompt (template + brief).
#
# The caller passes in the deterministic brief produced by
# coach_brief_render_from_digest. This function emits the framing template
# followed by the brief, suitable for handing to the AI dispatcher.
#
# Inputs (positional):
#   1: flow_type
#   2: brief - deterministic brief text produced by coach_brief_render_from_digest
coach_build_framing_prompt() {
    local flow_type="${1:-status}"
    local brief="${2:-}"

    coach_build_framing_template "$flow_type"
    printf '\nDeterministic brief:\n%s\n' "$brief"
}
