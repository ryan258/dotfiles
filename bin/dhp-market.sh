#!/bin/bash
set -e

# dhp-market.sh - Market Analyst dispatcher (Swarm Edition)
# SEO research, trend analysis, audience insights

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

dhp_dispatch \
    "Market Analysis" \
    "moonshotai/kimi-k2:free" \
    "$HOME/Documents/AI_Staff_HQ_Outputs/Strategy/Market_Research" \
    "MARKET_MODEL" \
    "DHP_MARKET_OUTPUT_DIR" \
    "
--- MARKET ANALYSIS OBJECTIVES ---
Conduct a comprehensive market analysis covering:
1. Keyword opportunities and SEO potential (high volume, low competition)
2. Current market trends, emerging patterns, and unmet needs
3. Target audience insights (demographics, psychographics, pain points)
4. Competitive landscape overview (major players, gaps, positioning)

DELIVERABLE: A detailed market analysis report with actionable strategic recommendations." \
    "0.7" \
    "$@"
