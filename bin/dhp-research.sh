#!/bin/bash
set -e

# dhp-research.sh - Academic Researcher dispatcher (Swarm Edition)
# Research organization, source summarization, knowledge synthesis

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

dhp_dispatch \
    "Research Synthesis" \
    "xiaomi/mimo-v2-flash:free" \
    "$HOME/Documents/AI_Staff_HQ_Outputs/Personal_Development/Research" \
    "RESEARCH_MODEL" \
    "DHP_RESEARCH_OUTPUT_DIR" \
    "
--- RESEARCH SYNTHESIS OBJECTIVES ---
Conduct a deep dive research synthesis covering:
1. Key themes, main arguments, and foundational concepts
2. Structured organization of findings (taxonomy or framework)
3. Important connections, patterns, and contradictions across sources
4. Suggested next research directions and open questions

DELIVERABLE: A structured, academic-grade research report." \
    "0.5" \
    "$@"
