#!/bin/bash
set -e

# dhp-stoic.sh - Stoic Coach dispatcher (Swarm Edition)
# Mindset coaching, reflections, journaling prompts

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

dhp_dispatch \
    "Stoic Coaching" \
    "xiaomi/mimo-v2-flash:free" \
    "$HOME/Documents/AI_Staff_HQ_Outputs/Personal_Development/Stoic_Coaching" \
    "STOIC_MODEL" \
    "DHP_STOIC_OUTPUT_DIR" \
    "
--- STOIC COACHING OBJECTIVES ---
Provide guidance based on Stoic philosophy:
1. Reframe the user's situation through Stoic principles (View from Above, Dichotomy of Control)
2. Distinguish clearly between what is within control vs. outside it
3. Recommend practical actions, exercises, or reflections
4. Cite relevant teachings (Marcus Aurelius, Seneca, Epictetus) where appropriate

DELIVERABLE: A compassionate but firm coaching response, practical and grounded." \
    "0.3" \
    "$@"
