#!/usr/bin/env bash
set -euo pipefail

# dhp-creative.sh - Creative Writer dispatcher (Swarm Edition)
# Story telling, script writing, creative direction

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

dhp_dispatch \
    "Creative Workflow" \
    "moonshotai/kimi-k2:free" \
    "$HOME/Documents/AI_Staff_HQ_Outputs/Creative/Stories" \
    "CREATIVE_MODEL" \
    "DHP_CREATIVE_OUTPUT_DIR" \
    "
--- CREATIVE REQUIREMENTS ---
Deliver a 'Complete Story Masterpiece':
1. Develop a comprehensive story foundation (structure, characters, world-building).
2. WRITE THE COMPLETE STORY PROSE (approx. 2000-3000 words).
   - Must be fully written, scene-by-scene.
   - Use high-quality narrative prose, dialogue, and sensory details.
   - Do NOT just summarize acts; WRITE them.
3. Integrate all elements into a single masterpiece document.

DELIVERABLE: Return a single, well-formatted markdown document containing the full story prose." \
    "0.85" \
    "$@"
