#!/bin/bash
set -e # Exit immediately if a command fails

# dhp-finance.sh - Financial Strategy dispatcher
# Dedicated to Tax, S-Corp, R&D Credits, and Financial Administration

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

dhp_dispatch \
    "Financial Strategy" \
    "moonshotai/kimi-k2:free" \
    "$HOME/Documents/AI_Staff_HQ_Outputs/Strategy/Finance" \
    "FINANCE_MODEL" \
    "DHP_FINANCE_OUTPUT_DIR" \
    "Analyze the following inputs and provide financial and tax optimization advice:

--- FINANCIAL CONTEXT ---
I'm a former software engineer who was diagnosed with multiple sclerosis in 2022 and currently on Medicare disability. I am transitioning to independent AI research (an R&D Lab model). I need to optimize for:
1. **Tax Efficiency:** S-Corp election, Section 174 R&D credits, Home Office deductions.
2. **Benefits Protection:** Managing income relative to Medicare SGA (Substantial Gainful Activity) limits.
3. **Entity Structure:** LLC vs S-Corp tradeoffs for a single-member R&D lab.

--- OBJECTIVES ---
1. **Compliance:** Ensure all advice considers Medicare disability constraints.
2. **Optimization:** Maximize deductions for legitimate R&D activities.
3. **Actionable Steps:** Provide specific administrative next steps (e.g., forms to file, logs to keep).

DELIVERABLE: A focused financial strategy and administrative checklist." \
    "0.4" \
    "$@"
