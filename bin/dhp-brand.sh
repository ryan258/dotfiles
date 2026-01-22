#!/bin/bash
set -e

# dhp-brand.sh - Brand Builder dispatcher (Swarm Edition)
# Brand positioning, voice/tone, competitive analysis

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

dhp_dispatch \
    "Brand Strategy" \
    "openrouter/polaris-alpha" \
    "$HOME/Documents/AI_Staff_HQ_Outputs/Strategy/Brand" \
    "DHP_BRAND_MODEL" \
    "DHP_BRAND_OUTPUT_DIR" \
    "
--- BRAND STRATEGY OBJECTIVES ---
Develop a comprehensive brand strategy covering:
1. Core brand attributes and values
2. Voice and tone recommendations (with specific style examples)
3. Competitive differentiation opportunities
4. Key messaging pillars and tagline explorations

DELIVERABLE: A detailed brand strategy document or playbook." \
    "0.7" \
    "$@"
