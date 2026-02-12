#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/dhp-shared.sh"

dhp_dispatch \
    "Copywriting" \
    "moonshotai/kimi-k2:free" \
    "$HOME/Documents/AI_Staff_HQ_Outputs/Creative/Copywriting" \
    "CREATIVE_MODEL" \
    "DHP_COPY_OUTPUT_DIR" \
    "
--- COPYWRITING OBJECTIVES ---
Develop compelling copy including:
1. Attention-grabbing headlines and subheadlines
2. Benefit-driven body copy emphasizing value propositions
3. Clear, strong Calls-to-Action (CTA)
4. Persuasive rhetoric tailored to the target audience

DELIVERABLE: A ready-to-use copy document with formatting." \
    "0.7" \
    "$@"
