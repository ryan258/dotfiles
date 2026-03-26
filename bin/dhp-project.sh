#!/usr/bin/env bash
set -euo pipefail

# dhp-project.sh: Multi-specialist project orchestrator
# Coordinates multiple AI specialists for complex project briefs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
source "$SCRIPT_DIR/dhp-shared.sh"

dhp_setup_env
dhp_parse_flags "$@"
if [ ${#REMAINING_ARGS[@]} -gt 0 ]; then
    set -- "${REMAINING_ARGS[@]}"
else
    set --
fi

validate_dependencies curl jq
ensure_api_key OPENROUTER_API_KEY

if [ $# -eq 0 ]; then
    cat >&2 <<EOF
Usage: $0 [--brain] [--verbose] [--temperature X] [--stream] "<project description>"

Example:
  $0 "Launch new blog series on AI productivity"
EOF
    die "dhp-project.sh requires a project description." "$EXIT_INVALID_ARGS"
fi

PROJECT_DESC=$(sanitize_input "$*")
OUTPUT_DIR_FINAL=$(default_output_dir "$HOME/Documents/AI_Staff_HQ_Outputs/Strategy/Projects" "DHP_PROJECT_OUTPUT_DIR")
mkdir -p "$OUTPUT_DIR_FINAL"
PROJECT_SLUG=$(slugify "$PROJECT_DESC")
PROJECT_OUTPUT_FILE="$OUTPUT_DIR_FINAL/${PROJECT_SLUG}.md"

COMMON_FLAGS=()
if [ "$USE_VERBOSE" = "true" ]; then
    COMMON_FLAGS+=(--verbose)
fi
if [ "$USE_STREAMING" = "true" ]; then
    COMMON_FLAGS+=(--stream)
fi
if [ "$USE_BRAIN" = "true" ]; then
    COMMON_FLAGS+=(--brain)
fi
if [ -n "$PARAM_TEMPERATURE" ]; then
    COMMON_FLAGS+=(--temperature "$PARAM_TEMPERATURE")
fi

PROJECT_TEMP_FILES=()
_dhp_project_cleanup() {
    if [ ${#PROJECT_TEMP_FILES[@]} -gt 0 ]; then
        rm -f "${PROJECT_TEMP_FILES[@]}" 2>/dev/null || true
    fi
}
trap _dhp_project_cleanup INT TERM EXIT

run_phase() {
    local phase_label="$1"
    local dispatcher="$2"
    local prompt="$3"
    local dispatcher_cmd=""
    local tmp_file=""

    dispatcher_cmd="$(dhp_resolve_dispatcher_command "$dispatcher" "$DOTFILES_DIR")" || {
        echo "Error: dispatcher '$dispatcher' is unavailable." >&2
        return 1
    }

    tmp_file=$(create_temp_file "dhp-project-phase") || return 1
    PROJECT_TEMP_FILES+=("$tmp_file")

    echo "$phase_label..." >&2
    if [ "$USE_STREAMING" = "true" ] || [ "$USE_VERBOSE" = "true" ]; then
        if ! printf '%s' "$prompt" | "$dispatcher_cmd" "${COMMON_FLAGS[@]}" | tee /dev/stderr > "$tmp_file"; then
            return 1
        fi
    else
        if ! printf '%s' "$prompt" | "$dispatcher_cmd" "${COMMON_FLAGS[@]}" > "$tmp_file"; then
            return 1
        fi
    fi

    cat "$tmp_file"
}

echo "========================================" >&2
echo "Multi-Specialist Project Orchestration" >&2
echo "========================================" >&2
echo "Project: $PROJECT_DESC" >&2
echo "" >&2

MARKET_PROMPT="Analyze the market opportunity for: $PROJECT_DESC

Provide:
- Target audience analysis
- SEO keyword opportunities
- Competitive landscape
- Market trends
- Success metrics"

MARKET_ANALYSIS="$(run_phase "📊 Phase 1: Market Research (Market Analyst)" "market" "$MARKET_PROMPT")" || {
    die "Phase 1 (Market Research) failed." "$EXIT_SERVICE_ERROR"
}

BRAND_PROMPT="Define brand positioning for: $PROJECT_DESC

Market Context:
$MARKET_ANALYSIS

Provide:
- Unique value proposition
- Brand voice and tone
- Differentiation strategy
- Messaging pillars"

BRAND_STRATEGY="$(run_phase "🎨 Phase 2: Brand Positioning (Brand Builder)" "brand" "$BRAND_PROMPT")" || {
    die "Phase 2 (Brand Positioning) failed." "$EXIT_SERVICE_ERROR"
}

STRATEGY_PROMPT="Create a strategic plan for: $PROJECT_DESC

Market Analysis:
$MARKET_ANALYSIS

Brand Strategy:
$BRAND_STRATEGY

Provide:
- Project timeline and milestones
- Resource allocation
- Risk assessment
- Success metrics
- Action items prioritized"

STRATEGIC_PLAN="$(run_phase "🎯 Phase 3: Strategic Planning (Chief of Staff)" "strategy" "$STRATEGY_PROMPT")" || {
    die "Phase 3 (Strategic Planning) failed." "$EXIT_SERVICE_ERROR"
}

CONTENT_PROMPT="Develop content strategy for: $PROJECT_DESC

Strategic Plan:
$STRATEGIC_PLAN

Brand Guidelines:
$BRAND_STRATEGY

Provide:
- Content topics and themes
- Publishing schedule
- SEO optimization plan
- Content formats"

CONTENT_STRATEGY="$(run_phase "📝 Phase 4: Content Strategy (Content Specialist)" "content" "$CONTENT_PROMPT")" || {
    die "Phase 4 (Content Strategy) failed." "$EXIT_SERVICE_ERROR"
}

COPY_PROMPT="Create promotional copy for: $PROJECT_DESC

Content Strategy:
$CONTENT_STRATEGY

Brand Voice:
$BRAND_STRATEGY

Provide:
- Launch announcement copy
- Email sequence outline
- Social media hooks
- Call-to-action variations"

MARKETING_COPY="$(run_phase "✍️  Phase 5: Marketing Copy (Copywriter)" "copy" "$COPY_PROMPT")" || {
    die "Phase 5 (Marketing Copy) failed." "$EXIT_SERVICE_ERROR"
}

PROJECT_BRIEF="$(cat <<EOF
# Project Brief: $PROJECT_DESC

**Generated:** $(date '+%Y-%m-%d %H:%M')
**Specialists Consulted:** 5 (Market Analyst, Brand Builder, Chief of Staff, Content Specialist, Copywriter)

---

## 1. Market Research

$MARKET_ANALYSIS

---

## 2. Brand Positioning

$BRAND_STRATEGY

---

## 3. Strategic Plan

$STRATEGIC_PLAN

---

## 4. Content Strategy

$CONTENT_STRATEGY

---

## 5. Marketing Copy

$MARKETING_COPY

---

## Next Steps

1. Review and refine this comprehensive brief
2. Break down action items into todo tasks
3. Set up project tracking and milestones
4. Begin content creation following the strategy
5. Execute marketing plan with provided copy

---

**Note:** This brief was generated through multi-specialist AI orchestration.
Review and adapt recommendations based on your specific context and constraints.
EOF
)"

printf '%s\n' "$PROJECT_BRIEF" | tee "$PROJECT_OUTPUT_FILE"
dhp_save_artifact "$PROJECT_OUTPUT_FILE" "$PROJECT_SLUG" "project" "dhp,project" "ai-staff-hq" "generation"

echo "" >&2
echo "SUCCESS: Project brief generated successfully." >&2
echo "Saved to: $PROJECT_OUTPUT_FILE" >&2
