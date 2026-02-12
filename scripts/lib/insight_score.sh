#!/usr/bin/env bash
# scripts/lib/insight_score.sh - Falsification gates and verdict scoring helpers
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_INSIGHT_SCORE_LOADED:-}" ]]; then
    return 0
fi
readonly _INSIGHT_SCORE_LOADED=true
readonly INSIGHT_MIN_INDEPENDENT_SOURCES=2

# Dependencies:
# - insight_store.sh sourced first by caller.
# - common.sh sourced by caller for shared helpers.
if ! command -v insight_get_hypothesis >/dev/null 2>&1; then
    echo "Error: insight_get_hypothesis is not available. Source scripts/lib/insight_store.sh before insight_score.sh." >&2
    return 1
fi
if [[ -z "${INSIGHT_TESTS_FILE:-}" || -z "${INSIGHT_EVIDENCE_FILE:-}" ]]; then
    echo "Error: Insight data file variables are not set. Source scripts/lib/config.sh before insight_score.sh." >&2
    return 1
fi

# Validate confidence value (0.0 to 1.0)
# Usage: insight_is_valid_confidence "0.65"
insight_is_valid_confidence() {
    local value="${1:-}"

    if [[ -z "$value" ]]; then
        return 1
    fi

    if ! [[ "$value" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]; then
        return 1
    fi

    awk -v v="$value" 'BEGIN { if (v >= 0 && v <= 1) exit 0; exit 1 }'
}

# Count independent evidence sources for a hypothesis
# Usage: insight_count_independent_sources "HYP-20260206-001"
insight_count_independent_sources() {
    local hypothesis_id="$1"

    if [[ ! -f "$INSIGHT_EVIDENCE_FILE" || ! -s "$INSIGHT_EVIDENCE_FILE" ]]; then
        echo "0"
        return 0
    fi

    awk -F'|' -v hyp="$hypothesis_id" '$2 == hyp && $6 != "" { print $6 }' "$INSIGHT_EVIDENCE_FILE" \
        | sort -u \
        | awk 'NF > 0 { count++ } END { print count + 0 }'
}

# Count evidence lines by direction (FOR, AGAINST, NEUTRAL)
# Usage: insight_count_evidence_direction "HYP-..." "against"
insight_count_evidence_direction() {
    local hypothesis_id="$1"
    local direction="$2"
    local target

    target=$(echo "$direction" | tr '[:lower:]' '[:upper:]')

    if [[ ! -f "$INSIGHT_EVIDENCE_FILE" || ! -s "$INSIGHT_EVIDENCE_FILE" ]]; then
        echo "0"
        return 0
    fi

    awk -F'|' -v hyp="$hypothesis_id" -v target="$target" '
        $2 == hyp {
            dir = toupper($4)
            if (dir == target) {
                count++
            }
        }
        END { print count + 0 }
    ' "$INSIGHT_EVIDENCE_FILE"
}

# Gate 1: At least one disconfirming test attempted (not just planned)
# Usage: insight_has_disconfirming_test_attempt "HYP-..."
insight_has_disconfirming_test_attempt() {
    local hypothesis_id="$1"

    if [[ ! -f "$INSIGHT_TESTS_FILE" || ! -s "$INSIGHT_TESTS_FILE" ]]; then
        return 1
    fi

    awk -F'|' -v hyp="$hypothesis_id" '
        $2 == hyp {
            test_type = toupper($4)
            status = toupper($7)
            if (test_type == "DISCONFIRMING" && status != "PLANNED" && status != "") {
                found = 1
                exit 0
            }
        }
        END { if (found) exit 0; exit 1 }
    ' "$INSIGHT_TESTS_FILE"
}

# Gate 3: Best counterargument and response are both present
# Usage: insight_has_counterargument_response "HYP-..."
insight_has_counterargument_response() {
    local hypothesis_id="$1"
    local record
    local counterargument
    local response

    record=$(insight_get_hypothesis "$hypothesis_id") || return 1
    IFS='|' read -r _ _ _ _ _ _ _ _ counterargument response <<< "$record"

    [[ -n "$counterargument" && -n "$response" ]]
}

# Gate 4: Updated confidence must differ from prior confidence
# Usage: insight_confidence_updated "0.50" "0.63"
insight_confidence_updated() {
    local prior="${1:-}"
    local updated="${2:-}"

    insight_is_valid_confidence "$prior" || return 1
    insight_is_valid_confidence "$updated" || return 1

    awk -v p="$prior" -v u="$updated" '
        BEGIN {
            diff = u - p
            if (diff < 0) diff = -diff
            if (diff > 0.0000001) exit 0
            exit 1
        }
    '
}

# Return gate summary as key=value lines
# Usage: insight_gate_report "HYP-..." "0.63"
insight_gate_report() {
    local hypothesis_id="$1"
    local updated_confidence="${2:-}"
    local has_disconfirming=0
    local independent_sources=0
    local has_counterargument=0
    local confidence_updated=0
    local record
    local prior_confidence

    if insight_has_disconfirming_test_attempt "$hypothesis_id"; then
        has_disconfirming=1
    fi

    independent_sources=$(insight_count_independent_sources "$hypothesis_id")

    if insight_has_counterargument_response "$hypothesis_id"; then
        has_counterargument=1
    fi

    record=$(insight_get_hypothesis "$hypothesis_id") || return 1
    IFS='|' read -r _ _ _ _ _ prior_confidence _ _ _ _ <<< "$record"

    if insight_confidence_updated "$prior_confidence" "$updated_confidence"; then
        confidence_updated=1
    fi

    printf '%s\n' "has_disconfirming_test=$has_disconfirming"
    printf '%s\n' "independent_sources=$independent_sources"
    printf '%s\n' "has_counterargument=$has_counterargument"
    printf '%s\n' "confidence_updated=$confidence_updated"
}

# Recommend verdict based on gate compliance + evidence balance
# Usage: insight_recommend_verdict "HYP-..." "0.63"
insight_recommend_verdict() {
    local hypothesis_id="$1"
    local updated_confidence="$2"
    local gate_line
    local has_disconfirming=0
    local independent_sources=0
    local has_counterargument=0
    local confidence_updated=0
    local evidence_for=0
    local evidence_against=0

    while IFS= read -r gate_line; do
        case "$gate_line" in
            has_disconfirming_test=*) has_disconfirming="${gate_line#*=}" ;;
            independent_sources=*) independent_sources="${gate_line#*=}" ;;
            has_counterargument=*) has_counterargument="${gate_line#*=}" ;;
            confidence_updated=*) confidence_updated="${gate_line#*=}" ;;
        esac
    done < <(insight_gate_report "$hypothesis_id" "$updated_confidence")

    if [[ "$has_disconfirming" != "1" || "$independent_sources" -lt "$INSIGHT_MIN_INDEPENDENT_SOURCES" || "$has_counterargument" != "1" || "$confidence_updated" != "1" ]]; then
        echo "INCONCLUSIVE"
        return 0
    fi

    evidence_for=$(insight_count_evidence_direction "$hypothesis_id" "FOR")
    evidence_against=$(insight_count_evidence_direction "$hypothesis_id" "AGAINST")

    if (( evidence_against > evidence_for )); then
        echo "FALSIFIED"
    elif (( evidence_for > evidence_against )); then
        echo "SUPPORTED"
    else
        echo "INCONCLUSIVE"
    fi
}
