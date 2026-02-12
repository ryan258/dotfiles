# Falsification-First Insight Module

This module adds a hypothesis workflow focused on disproof-before-belief:

1. Create a hypothesis.
2. Plan and run a disconfirming test.
3. Add evidence with provenance.
4. Produce a verdict with hard support gates.

## Command

```bash
insight.sh <command> [options]
```

## Core Commands

```bash
# Create a hypothesis
insight.sh new "Claim text" --domain health --novelty 4 --prior 0.50

# Plan a disconfirming test
insight.sh test-plan HYP-20260206-001 --prediction "Expected failure" --fail-criterion "No measurable effect"

# Record test attempt/result
insight.sh test-result TST-20260206-001 --status attempted --result "Ran test with 10-day sample"

# Add evidence
insight.sh evidence add HYP-20260206-001 --direction against --strength 4 --source "paper://doi-or-link" --provenance "paper"

# Produce verdict with gate checks
insight.sh verdict HYP-20260206-001 --confidence 0.62 --counterargument "Selection bias" --response "Compared against baseline cohort"

# Weekly KPI summary
insight.sh weekly --low-spoons
```

## Data Files

All files live in `~/.config/dotfiles-data/`:

- `insight_hypotheses.txt`  
  `ID|CREATED_AT|DOMAIN|CLAIM|STATUS|PRIOR_CONFIDENCE|NOVELTY|NEXT_TEST|BEST_COUNTERARGUMENT|COUNTERARGUMENT_RESPONSE`
- `insight_tests.txt`  
  `TEST_ID|HYP_ID|CREATED_AT|TYPE|PREDICTION|FAIL_CRITERION|STATUS|RESULT`
- `insight_evidence.txt`  
  `EVID_ID|HYP_ID|TIMESTAMP|DIRECTION|STRENGTH|SOURCE|PROVENANCE|NOTE`
- `insight_verdicts.txt`  
  `HYP_ID|TIMESTAMP|VERDICT|CONFIDENCE|WHY|COUNTEREVIDENCE_SUMMARY`

## Support Gates

A hypothesis cannot end as `SUPPORTED` unless all gates pass:

1. At least one disconfirming test was attempted.
2. At least two independent evidence sources are logged.
3. Best counterargument and response are both present.
4. Verdict confidence changed from the prior confidence.

If any gate fails, a requested `SUPPORTED` verdict is downgraded to `INCONCLUSIVE`.
