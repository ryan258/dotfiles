#!/usr/bin/env bash
set -euo pipefail

# dhp-narrative.sh - Narrative Designer dispatcher (Swarm Edition)
# Story structure, plot development, character arcs

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

dhp_dispatch \
    "Narrative Design" \
    "moonshotai/kimi-k2:free" \
    "$HOME/Documents/AI_Staff_HQ_Outputs/Creative/Narratives" \
    "CREATIVE_MODEL" \
    "DHP_NARRATIVE_OUTPUT_DIR" \
    "
--- NARRATIVE DESIGN OBJECTIVES ---
Analyze and develop the narrative with focus on:
1. Story structure (3-act, Hero's Journey, or alternative models)
2. Plot coherence and scene progression
3. Character arcs, motivations, and conflicts
4. Key dramatic moments and pacing recommendations

DELIVERABLE: A comprehensive narrative design document tailored to the story concept." \
    "0.8" \
    "$@"
