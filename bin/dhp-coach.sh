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
    cat >&2 <<EOF
Usage: echo "prompt" | $(basename "$0") [options]
   or: $(basename "$0") "prompt" [options]
EOF
    die "dhp-coach.sh requires a prompt." "$EXIT_INVALID_ARGS"
fi

MODEL_FINAL="${COACH_MODEL:-nvidia/nemotron-3-nano-30b-a3b:free}"
TEMPERATURE_FINAL="${PARAM_TEMPERATURE:-${AI_BRIEFING_TEMPERATURE:-0.25}}"

COACH_SYSTEM_BRIEF="You are a fast, grounded daily coaching specialist.

Rules:
- Answer in one pass with no swarm planning or task decomposition.
- Follow the schema requested by the prompt exactly.
- Reuse the exact section headings requested by the prompt.
- Use the provided context directly and keep the response concrete.
- Do not invent task completions, publish events, commit counts, or dates that are not explicitly present.
- Do not invent page names, homepage sections, paragraph states, file paths, or draft status unless explicitly present.
- If context is thin, say so plainly instead of inventing work.
- Keep the response concise, operational, and specific.
- Do not mention internal tooling, dispatchers, or model selection."

ENHANCED_BRIEF="$COACH_SYSTEM_BRIEF

INPUT:
$PIPED_CONTENT"

OUTPUT_DIR_FINAL=""
OUTPUT_FILE=""
if [ "${AI_COACH_SAVE_OUTPUTS:-false}" = "true" ] || [ -n "${DHP_COACH_OUTPUT_DIR:-}" ]; then
    OUTPUT_DIR_FINAL=$(default_output_dir "$HOME/Documents/AI_Staff_HQ_Outputs/Strategy/Coach" "DHP_COACH_OUTPUT_DIR")
    mkdir -p "$OUTPUT_DIR_FINAL"
    OUTPUT_FILE="$OUTPUT_DIR_FINAL/$(slugify "$PIPED_CONTENT").md"
fi

echo "AI coach: querying $MODEL_FINAL..." >&2
START_TS=$(date +%s)

if [ "$USE_STREAMING" = "true" ]; then
    if [ -n "$OUTPUT_FILE" ]; then
        if DHP_TEMPERATURE="$TEMPERATURE_FINAL" call_openrouter "$MODEL_FINAL" "$ENHANCED_BRIEF" "--stream" "dhp-coach" | tee "$OUTPUT_FILE"; then
            :
        else
            die "AI coach request failed." "$EXIT_SERVICE_ERROR"
        fi
    else
        if DHP_TEMPERATURE="$TEMPERATURE_FINAL" call_openrouter "$MODEL_FINAL" "$ENHANCED_BRIEF" "--stream" "dhp-coach"; then
            :
        else
            die "AI coach request failed." "$EXIT_SERVICE_ERROR"
        fi
    fi
else
    RESPONSE=""
    if RESPONSE=$(DHP_TEMPERATURE="$TEMPERATURE_FINAL" call_openrouter_sync "$MODEL_FINAL" "$ENHANCED_BRIEF" "dhp-coach"); then
        if [ -n "$OUTPUT_FILE" ]; then
            printf '%s\n' "$RESPONSE" | tee "$OUTPUT_FILE"
        else
            printf '%s\n' "$RESPONSE"
        fi
    else
        die "AI coach request failed." "$EXIT_SERVICE_ERROR"
    fi
fi

ELAPSED=$(( $(date +%s) - START_TS ))
echo "AI coach: response received in ${ELAPSED}s." >&2
