#!/bin/bash
set -e

# dhp-tech.sh - Technical Analyst dispatcher (Swarm Edition)
# Code analysis, bug fixing, automation engineering

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

dhp_dispatch \
    "Technical Analysis" \
    "xiaomi/mimo-v2-flash:free" \
    "$HOME/Documents/AI_Staff_HQ_Outputs/Technical/Code_Analysis" \
    "TECH_MODEL" \
    "DHP_TECH_OUTPUT_DIR" \
    "Analyze the following code/request:

--- TECHNICAL OBJECTIVES ---
1. Analyze the provided code or request for bugs, errors, or optimization opportunities.
2. Identify the root cause of any issues.
3. Provide the corrected code or solution.
4. Explain the fix and any best practices applied.

DELIVERABLE: A technical report including Bug Analysis, The Fix, and Corrected Code block." \
    "0.2" \
    "$@"
