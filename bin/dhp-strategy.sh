#!/bin/bash
set -e # Exit immediately if a command fails

# dhp-strategy.sh - Strategic Analysis dispatcher (Swarm Edition)
# High-level analysis, synthesis, and decision support

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

dhp_dispatch \
    "Strategic Analysis" \
    "openrouter/polaris-alpha" \
    "$HOME/Documents/AI_Staff_HQ_Outputs/Strategy/Analysis" \
    "DHP_STRATEGY_MODEL" \
    "DHP_STRATEGY_OUTPUT_DIR" \
    "Analyze the following inputs and provide strategic direction:

--- STRATEGIC ANALYSIS CONTEXT ---
I'm a former software engineer who was diagnosed with multiple sclerosis in 2022 and currently on Medicare disability. I have brain fog, fatigue, and other symptoms that make it difficult to work full-time. Currently I'm all in as an independent AI researcher, developing my skills and portfolio in wielding AI for fun, productivity and profit.

--- STRATEGIC ANALYSIS OBJECTIVES ---
1. **Key Insights:** Synthesize main patterns, observations, and hidden dynamics.
2. **Strategic Recommendations:** Provide specific, high-leverage next actions.
3. **Risk/Opportunity Assessment:** Identify potential pitfalls and upside vectors.
4. **Execution Framework:** High-level roadmap or immediate next steps.

DELIVERABLE: A high-level strategic analysis and decision support document." \
    "0.6" \
    "$@"
