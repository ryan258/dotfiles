#!/usr/bin/env bash
set -euo pipefail

# dhp-project.sh: Multi-Specialist Project Orchestrator
# Coordinates multiple AI specialists for complex projects

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
CONFIG_LIB="$DOTFILES_DIR/scripts/lib/config.sh"

if [ -f "$CONFIG_LIB" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_LIB"
else
    echo "Error: configuration library not found at $CONFIG_LIB" >&2
    exit 1
fi

# Dependency check
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    echo "Error: curl and jq are required." >&2
    exit 1
fi

# API key validation
if [ -z "${OPENROUTER_API_KEY:-}" ]; then
    echo "Error: OPENROUTER_API_KEY not set in .env" >&2
    exit 1
fi

# Get project description
if [ $# -eq 0 ]; then
    echo "Usage: $0 \"<project description>\"" >&2
    echo "" >&2
    echo "Example: $0 \"Launch new blog series on AI productivity\"" >&2
    exit 1
fi

PROJECT_DESC="$*"

echo "========================================" >&2
echo "Multi-Specialist Project Orchestration" >&2
echo "========================================" >&2
echo "Project: $PROJECT_DESC" >&2
echo "" >&2

# Phase 1: Market Research
echo "📊 Phase 1: Market Research (Market Analyst)..." >&2
MARKET_PROMPT="Analyze the market opportunity for: $PROJECT_DESC

Provide:
- Target audience analysis
- SEO keyword opportunities
- Competitive landscape
- Market trends
- Success metrics"

MARKET_ANALYSIS=$(echo "$MARKET_PROMPT" | "$DOTFILES_DIR/bin/dhp-market.sh") || {
    echo "Error: Phase 1 (Market Research) failed." >&2
    exit 1
}

# Phase 2: Brand Positioning
echo "🎨 Phase 2: Brand Positioning (Brand Builder)..." >&2
BRAND_PROMPT="Define brand positioning for: $PROJECT_DESC

Market Context:
$MARKET_ANALYSIS

Provide:
- Unique value proposition
- Brand voice and tone
- Differentiation strategy
- Messaging pillars"

BRAND_STRATEGY=$(echo "$BRAND_PROMPT" | "$DOTFILES_DIR/bin/dhp-brand.sh") || {
    echo "Error: Phase 2 (Brand Positioning) failed." >&2
    exit 1
}

# Phase 3: Strategic Plan
echo "🎯 Phase 3: Strategic Planning (Chief of Staff)..." >&2
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

STRATEGIC_PLAN=$(echo "$STRATEGY_PROMPT" | "$DOTFILES_DIR/bin/dhp-strategy.sh") || {
    echo "Error: Phase 3 (Strategic Planning) failed." >&2
    exit 1
}

# Phase 4: Content Strategy
echo "📝 Phase 4: Content Strategy (Content Specialist)..." >&2
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

CONTENT_STRATEGY=$(echo "$CONTENT_PROMPT" | "$DOTFILES_DIR/bin/dhp-content.sh") || {
    echo "Error: Phase 4 (Content Strategy) failed." >&2
    exit 1
}

# Phase 5: Marketing Copy
echo "✍️  Phase 5: Marketing Copy (Copywriter)..." >&2
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

MARKETING_COPY=$(echo "$COPY_PROMPT" | "$DOTFILES_DIR/bin/dhp-copy.sh") || {
    echo "Error: Phase 5 (Marketing Copy) failed." >&2
    exit 1
}

# Generate comprehensive project brief
echo "" >&2
echo "✅ Multi-Specialist Orchestration Complete" >&2
echo "========================================" >&2
echo "" >&2

# Output comprehensive project brief
cat <<EOF
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

echo "" >&2
echo "SUCCESS: Project brief generated successfully." >&2
echo "TIP: Redirect output to a file: dhp-project \"...\" > project-brief.md" >&2
