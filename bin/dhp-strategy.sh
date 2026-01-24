#!/bin/bash
set -e # Exit immediately if a command fails

# dhp-strategy.sh - Strategic Analysis dispatcher (Swarm Edition)
# High-level analysis, synthesis, and decision support

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

dhp_dispatch \
    "Strategic Analysis" \
    "xiaomi/mimo-v2-flash:free" \
    "$HOME/Documents/AI_Staff_HQ_Outputs/Strategy/Analysis" \
    "STRATEGY_MODEL" \
    "DHP_STRATEGY_OUTPUT_DIR" \
    "Analyze the following inputs and provide strategic direction:

--- STRATEGIC ANALYSIS CONTEXT ---
I'm a former software engineer who was diagnosed with multiple sclerosis in 2022 and currently on Medicare disability. I have brain fog, fatigue, and other symptoms that make it difficult to work full-time. Currently I'm all in as an independent AI researcher, developing my skills and portfolio in wielding AI for fun, productivity and profit.

--- STRATEGIC ANALYSIS OBJECTIVES ---
1. **Key Insights:** Synthesize main patterns, observations, and hidden dynamics relative to CAPABILITY and RESEARCH.
2. **Strategic Recommendations:** Provide specific, high-leverage next actions for R&D.
3. **Risk/Opportunity Assessment:** Identify potential pitfalls and upside vectors.
4. **Execution Framework:** High-level roadmap or immediate next steps.

IMPORTANT EXCLUSION: Do NOT provide advice on Taxes, S-Corps, Legal Entity structures, or Financial Administration. These are handled by a separate specialist. Focus ONLY on Research, Capability, and Health/Energy management.

DELIVERABLE: A high-level strategic analysis and decision support document." \
    "0.6" \
    "$@"
