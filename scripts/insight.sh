#!/usr/bin/env bash
# insight.sh - Falsification-first hypothesis workflow
#
# Create hypotheses, plan disconfirming tests, collect evidence, and produce
# verdicts with gate checks that prioritize disproof over belief.
#
# Usage: insight.sh <command> [options]
#
# Commands:
#   new <claim>                 Create a new hypothesis
#   test-plan <hyp_id>          Add a disconfirming test plan
#   test-result <test_id>       Mark a test as attempted/completed
#   evidence add <hyp_id>       Add evidence for a hypothesis
#   verdict <hyp_id>            Generate/store a verdict with gate checks
#   weekly [--low-spoons]       Weekly KPI summary
#   help                        Show this help

set -euo pipefail

INSIGHT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$INSIGHT_SCRIPT_DIR/lib/common.sh"
source "$INSIGHT_SCRIPT_DIR/lib/config.sh"
source "$INSIGHT_SCRIPT_DIR/lib/insight_store.sh"
source "$INSIGHT_SCRIPT_DIR/lib/insight_score.sh"

ensure_insight_data_files || die "Failed to initialize insight data files" "$EXIT_ERROR"

show_help() {
    echo "Usage: $(basename "$0") <command> [options]"
    echo ""
    echo "Commands:"
    echo "  new <claim> [--domain <name>] [--novelty <1-5>] [--prior <0-1>] [--next-test <text>]"
    echo "  test-plan <hyp_id> [--prediction <text>] [--fail-criterion <text>]"
    echo "  test-result <test_id> --status <attempted|passed|failed|inconclusive> --result <text>"
    echo "  evidence add <hyp_id> --direction <for|against|neutral> --strength <1-5> --source <text> [--provenance <text>] [--note <text>]"
    echo "  verdict <hyp_id> [--verdict <supported|falsified|inconclusive>] [--confidence <0-1>] [--why <text>] [--counterargument <text>] [--response <text>]"
    echo "  weekly [--low-spoons]"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") new \"Caffeine before noon reduces brain fog\" --domain health --novelty 4"
    echo "  $(basename "$0") test-plan HYP-20260206-001 --prediction \"No measurable improvement\" --fail-criterion \"No delta after 7 days\""
    echo "  $(basename "$0") evidence add HYP-20260206-001 --direction against --strength 4 --source \"journal://2026-02-06\""
    echo "  $(basename "$0") verdict HYP-20260206-001 --confidence 0.63 --counterargument \"Placebo effect\" --response \"Matched against non-caffeine days\""
}

require_value() {
    local option_name="$1"
    local option_value="${2:-}"

    if [[ -z "$option_value" ]]; then
        echo "Error: $option_name requires a value" >&2
        return 1
    fi
}

normalize_verdict() {
    local value="$1"
    local upper

    upper=$(echo "$value" | tr '[:lower:]' '[:upper:]')
    case "$upper" in
        SUPPORTED|FALSIFIED|INCONCLUSIVE) echo "$upper" ;;
        *)
            echo "Error: Invalid verdict '$value' (expected supported|falsified|inconclusive)" >&2
            return 1
            ;;
    esac
}

normalize_direction() {
    local value="$1"
    local upper

    upper=$(echo "$value" | tr '[:lower:]' '[:upper:]')
    case "$upper" in
        FOR|AGAINST|NEUTRAL) echo "$upper" ;;
        *)
            echo "Error: Invalid direction '$value' (expected for|against|neutral)" >&2
            return 1
            ;;
    esac
}

normalize_test_status() {
    local value="$1"
    local upper

    upper=$(echo "$value" | tr '[:lower:]' '[:upper:]')
    case "$upper" in
        ATTEMPTED|PASSED|FAILED|INCONCLUSIVE) echo "$upper" ;;
        *)
            echo "Error: Invalid test status '$value' (expected attempted|passed|failed|inconclusive)" >&2
            return 1
            ;;
    esac
}

date_days_ago() {
    local days="$1"
    if date -v-"$days"d +%Y-%m-%d >/dev/null 2>&1; then
        date -v-"$days"d +%Y-%m-%d
    else
        date -d "$days days ago" +%Y-%m-%d
    fi
}

load_hypothesis() {
    local hypothesis_id="$1"
    local record

    record=$(insight_get_hypothesis "$hypothesis_id") || {
        echo "Error: Hypothesis not found: $hypothesis_id" >&2
        return 1
    }

    IFS='|' read -r HYP_ID HYP_CREATED_AT HYP_DOMAIN HYP_CLAIM HYP_STATUS HYP_PRIOR_CONFIDENCE HYP_NOVELTY HYP_NEXT_TEST HYP_COUNTERARGUMENT HYP_COUNTERARGUMENT_RESPONSE <<< "$record"
}

save_hypothesis() {
    local updated_line

    updated_line="${HYP_ID}|${HYP_CREATED_AT}|${HYP_DOMAIN}|${HYP_CLAIM}|${HYP_STATUS}|${HYP_PRIOR_CONFIDENCE}|${HYP_NOVELTY}|${HYP_NEXT_TEST}|${HYP_COUNTERARGUMENT}|${HYP_COUNTERARGUMENT_RESPONSE}"
    insight_replace_hypothesis "$HYP_ID" "$updated_line"
}

cmd_new() {
    local claim="${1:-}"
    local domain="general"
    local novelty="3"
    local prior_confidence="0.50"
    local next_test=""
    local counterargument=""
    local response=""
    local hypothesis_id
    local created_at
    local record

    if [[ -z "$claim" ]]; then
        echo "Error: Claim text is required" >&2
        echo "Usage: $(basename "$0") new <claim> [--domain <name>] [--novelty <1-5>] [--prior <0-1>]" >&2
        return 1
    fi
    shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain)
                require_value "--domain" "${2:-}" || return 1
                domain="$2"
                shift 2
                ;;
            --novelty)
                require_value "--novelty" "${2:-}" || return 1
                novelty="$2"
                shift 2
                ;;
            --prior|--prior-confidence)
                require_value "--prior" "${2:-}" || return 1
                prior_confidence="$2"
                shift 2
                ;;
            --next-test)
                require_value "--next-test" "${2:-}" || return 1
                next_test="$2"
                shift 2
                ;;
            --counterargument)
                require_value "--counterargument" "${2:-}" || return 1
                counterargument="$2"
                shift 2
                ;;
            --response)
                require_value "--response" "${2:-}" || return 1
                response="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option for new: $1" >&2
                return 1
                ;;
        esac
    done

    validate_numeric "$novelty" "novelty score" || return 1
    validate_range "$novelty" 1 5 "novelty score" || return 1

    if ! insight_is_valid_confidence "$prior_confidence"; then
        echo "Error: --prior must be a number between 0 and 1" >&2
        return 1
    fi

    hypothesis_id=$(insight_next_hypothesis_id)
    created_at="$(date '+%Y-%m-%d %H:%M:%S')"

    domain=$(normalize_insight_field "$domain")
    claim=$(normalize_insight_field "$claim")
    next_test=$(normalize_insight_field "$next_test")
    counterargument=$(normalize_insight_field "$counterargument")
    response=$(normalize_insight_field "$response")

    record="${hypothesis_id}|${created_at}|${domain}|${claim}|OPEN|${prior_confidence}|${novelty}|${next_test}|${counterargument}|${response}"
    insight_append_hypothesis "$record"

    echo "Created hypothesis: $hypothesis_id"
    echo "Status: OPEN"
}

cmd_test_plan() {
    local hypothesis_id="${1:-}"
    local prediction="The claim should fail when tested under independent evidence."
    local fail_criterion="Independent evidence contradicts the claim."
    local test_id
    local created_at
    local test_record

    if [[ -z "$hypothesis_id" ]]; then
        echo "Error: Hypothesis ID is required" >&2
        echo "Usage: $(basename "$0") test-plan <hyp_id> [--prediction <text>] [--fail-criterion <text>]" >&2
        return 1
    fi
    shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prediction)
                require_value "--prediction" "${2:-}" || return 1
                prediction="$2"
                shift 2
                ;;
            --fail-criterion)
                require_value "--fail-criterion" "${2:-}" || return 1
                fail_criterion="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option for test-plan: $1" >&2
                return 1
                ;;
        esac
    done

    load_hypothesis "$hypothesis_id" || return 1

    test_id=$(insight_next_test_id)
    created_at="$(date '+%Y-%m-%d %H:%M:%S')"

    prediction=$(normalize_insight_field "$prediction")
    fail_criterion=$(normalize_insight_field "$fail_criterion")

    test_record="${test_id}|${hypothesis_id}|${created_at}|DISCONFIRMING|${prediction}|${fail_criterion}|PLANNED|PENDING"
    insight_append_test "$test_record"

    HYP_STATUS="IN_TEST"
    HYP_NEXT_TEST="$fail_criterion"
    save_hypothesis || return 1

    echo "Created disconfirming test: $test_id"
    echo "Hypothesis moved to IN_TEST"
}

cmd_test_result() {
    local test_id="${1:-}"
    local status=""
    local result=""
    local test_record
    local hypothesis_id
    local created_at
    local test_type
    local prediction
    local fail_criterion
    local _old_status
    local _old_result
    local new_record

    if [[ -z "$test_id" ]]; then
        echo "Error: Test ID is required" >&2
        echo "Usage: $(basename "$0") test-result <test_id> --status <attempted|passed|failed|inconclusive> --result <text>" >&2
        return 1
    fi
    shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --status)
                require_value "--status" "${2:-}" || return 1
                status="$2"
                shift 2
                ;;
            --result)
                require_value "--result" "${2:-}" || return 1
                result="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option for test-result: $1" >&2
                return 1
                ;;
        esac
    done

    if [[ -z "$status" || -z "$result" ]]; then
        echo "Error: --status and --result are required for test-result" >&2
        return 1
    fi

    status=$(normalize_test_status "$status") || return 1
    result=$(normalize_insight_field "$result")

    test_record=$(insight_get_test "$test_id") || {
        echo "Error: Test not found: $test_id" >&2
        return 1
    }

    IFS='|' read -r _ hypothesis_id created_at test_type prediction fail_criterion _old_status _old_result <<< "$test_record"

    new_record="${test_id}|${hypothesis_id}|${created_at}|${test_type}|${prediction}|${fail_criterion}|${status}|${result}"
    insight_replace_test "$test_id" "$new_record"

    echo "Updated test $test_id -> $status"
}

cmd_evidence_add() {
    local hypothesis_id="${1:-}"
    local direction=""
    local strength="3"
    local source_text=""
    local provenance="unspecified"
    local note=""
    local evidence_id
    local timestamp
    local evidence_record

    if [[ -z "$hypothesis_id" ]]; then
        echo "Error: Hypothesis ID is required" >&2
        echo "Usage: $(basename "$0") evidence add <hyp_id> --direction <for|against|neutral> --strength <1-5> --source <text>" >&2
        return 1
    fi
    shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --direction)
                require_value "--direction" "${2:-}" || return 1
                direction="$2"
                shift 2
                ;;
            --strength)
                require_value "--strength" "${2:-}" || return 1
                strength="$2"
                shift 2
                ;;
            --source)
                require_value "--source" "${2:-}" || return 1
                source_text="$2"
                shift 2
                ;;
            --provenance)
                require_value "--provenance" "${2:-}" || return 1
                provenance="$2"
                shift 2
                ;;
            --note)
                require_value "--note" "${2:-}" || return 1
                note="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option for evidence add: $1" >&2
                return 1
                ;;
        esac
    done

    if [[ -z "$direction" || -z "$source_text" ]]; then
        echo "Error: --direction and --source are required" >&2
        return 1
    fi

    direction=$(normalize_direction "$direction") || return 1
    validate_numeric "$strength" "evidence strength" || return 1
    validate_range "$strength" 1 5 "evidence strength" || return 1

    load_hypothesis "$hypothesis_id" || return 1

    evidence_id=$(insight_next_evidence_id)
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    source_text=$(normalize_insight_field "$source_text")
    provenance=$(normalize_insight_field "$provenance")
    note=$(normalize_insight_field "$note")

    evidence_record="${evidence_id}|${hypothesis_id}|${timestamp}|${direction}|${strength}|${source_text}|${provenance}|${note}"
    insight_append_evidence "$evidence_record"

    if [[ "$HYP_STATUS" == "OPEN" ]]; then
        HYP_STATUS="IN_TEST"
        save_hypothesis || return 1
    fi

    echo "Added evidence: $evidence_id"
}

cmd_verdict() {
    local hypothesis_id="${1:-}"
    local requested_verdict=""
    local confidence=""
    local why=""
    local counterargument=""
    local response=""
    local final_verdict
    local recommended_verdict
    local final_confidence
    local has_disconfirming=0
    local independent_sources=0
    local has_counterargument=0
    local confidence_updated=0
    local gate_line
    local evidence_for
    local evidence_against
    local failed_gates=()
    local counterevidence_summary
    local verdict_timestamp
    local verdict_record

    if [[ -z "$hypothesis_id" ]]; then
        echo "Error: Hypothesis ID is required" >&2
        echo "Usage: $(basename "$0") verdict <hyp_id> [--confidence <0-1>] [--counterargument <text>] [--response <text>]" >&2
        return 1
    fi
    shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verdict)
                require_value "--verdict" "${2:-}" || return 1
                requested_verdict="$2"
                shift 2
                ;;
            --confidence)
                require_value "--confidence" "${2:-}" || return 1
                confidence="$2"
                shift 2
                ;;
            --why)
                require_value "--why" "${2:-}" || return 1
                why="$2"
                shift 2
                ;;
            --counterargument)
                require_value "--counterargument" "${2:-}" || return 1
                counterargument="$2"
                shift 2
                ;;
            --response)
                require_value "--response" "${2:-}" || return 1
                response="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option for verdict: $1" >&2
                return 1
                ;;
        esac
    done

    load_hypothesis "$hypothesis_id" || return 1

    if [[ -n "$counterargument" ]]; then
        HYP_COUNTERARGUMENT=$(normalize_insight_field "$counterargument")
    fi
    if [[ -n "$response" ]]; then
        HYP_COUNTERARGUMENT_RESPONSE=$(normalize_insight_field "$response")
    fi
    if [[ -n "$counterargument" || -n "$response" ]]; then
        save_hypothesis || return 1
    fi

    if [[ -n "$confidence" ]]; then
        if ! insight_is_valid_confidence "$confidence"; then
            echo "Error: --confidence must be a number between 0 and 1" >&2
            return 1
        fi
        final_confidence="$confidence"
    else
        final_confidence="$HYP_PRIOR_CONFIDENCE"
    fi

    while IFS= read -r gate_line; do
        case "$gate_line" in
            has_disconfirming_test=*) has_disconfirming="${gate_line#*=}" ;;
            independent_sources=*) independent_sources="${gate_line#*=}" ;;
            has_counterargument=*) has_counterargument="${gate_line#*=}" ;;
            confidence_updated=*) confidence_updated="${gate_line#*=}" ;;
        esac
    done < <(insight_gate_report "$hypothesis_id" "$final_confidence")

    recommended_verdict=$(insight_recommend_verdict "$hypothesis_id" "$final_confidence")

    if [[ -n "$requested_verdict" ]]; then
        final_verdict=$(normalize_verdict "$requested_verdict") || return 1
    else
        final_verdict="$recommended_verdict"
    fi

    if [[ "$final_verdict" == "SUPPORTED" ]]; then
        if [[ "$has_disconfirming" != "1" ]]; then
            failed_gates+=("No attempted disconfirming test")
        fi
        if [[ "$independent_sources" -lt 2 ]]; then
            failed_gates+=("Fewer than 2 independent evidence sources")
        fi
        if [[ "$has_counterargument" != "1" ]]; then
            failed_gates+=("Missing counterargument and/or response")
        fi
        if [[ "$confidence_updated" != "1" ]]; then
            failed_gates+=("Confidence unchanged from prior")
        fi
    fi

    if [[ "${#failed_gates[@]}" -gt 0 ]]; then
        final_verdict="INCONCLUSIVE"
    fi

    evidence_for=$(insight_count_evidence_direction "$hypothesis_id" "FOR")
    evidence_against=$(insight_count_evidence_direction "$hypothesis_id" "AGAINST")
    counterevidence_summary="FOR=${evidence_for}; AGAINST=${evidence_against}"

    if [[ -z "$why" ]]; then
        why="Recommended=${recommended_verdict}; gates(disconfirming=${has_disconfirming}, sources=${independent_sources}, counter=${has_counterargument}, confidence_updated=${confidence_updated})"
    fi

    why=$(normalize_insight_field "$why")
    counterevidence_summary=$(normalize_insight_field "$counterevidence_summary")
    verdict_timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    verdict_record="${hypothesis_id}|${verdict_timestamp}|${final_verdict}|${final_confidence}|${why}|${counterevidence_summary}"
    insight_append_verdict "$verdict_record"

    HYP_STATUS="$final_verdict"
    save_hypothesis || return 1

    echo "Verdict for $hypothesis_id: $final_verdict"
    if [[ "${#failed_gates[@]}" -gt 0 ]]; then
        echo "Support gates not met:"
        printf '  - %s\n' "${failed_gates[@]}"
    fi
}

cmd_weekly() {
    local low_spoons=0
    local cutoff_date
    local today
    local generated
    local killed
    local survived
    local promoted
    local calibration_shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --low-spoons)
                low_spoons=1
                shift
                ;;
            *)
                echo "Error: Unknown option for weekly: $1" >&2
                return 1
                ;;
        esac
    done

    cutoff_date="$(date_days_ago 6)"
    today="$(date +%Y-%m-%d)"

    generated=$(awk -F'|' -v cutoff="$cutoff_date" 'substr($2, 1, 10) >= cutoff { count++ } END { print count + 0 }' "$INSIGHT_HYPOTHESES_FILE")
    killed=$(awk -F'|' -v cutoff="$cutoff_date" 'substr($2, 1, 10) >= cutoff && toupper($3) == "FALSIFIED" { count++ } END { print count + 0 }' "$INSIGHT_VERDICTS_FILE")
    survived=$(awk -F'|' -v cutoff="$cutoff_date" 'substr($2, 1, 10) >= cutoff && toupper($3) == "SUPPORTED" { count++ } END { print count + 0 }' "$INSIGHT_VERDICTS_FILE")
    promoted=$(awk -F'|' -v cutoff="$cutoff_date" 'substr($2, 1, 10) >= cutoff && toupper($3) == "SUPPORTED" && ($4 + 0.0) >= 0.70 { count++ } END { print count + 0 }' "$INSIGHT_VERDICTS_FILE")

    calibration_shift=$(awk -F'|' -v cutoff="$cutoff_date" '
        FNR == NR {
            prior[$1] = $6 + 0.0
            next
        }
        substr($2, 1, 10) >= cutoff {
            if ($1 in prior) {
                diff = ($4 + 0.0) - prior[$1]
                if (diff < 0) diff = -diff
                sum += diff
                count++
            }
        }
        END {
            if (count == 0) {
                print "n/a"
            } else {
                printf "%.2f", (sum / count) * 100
            }
        }
    ' "$INSIGHT_HYPOTHESES_FILE" "$INSIGHT_VERDICTS_FILE")

    if [[ "$low_spoons" -eq 1 ]]; then
        echo "Week $cutoff_date to $today: generated=$generated killed=$killed survived=$survived promoted=$promoted calibration_shift=${calibration_shift}%"
        return 0
    fi

    echo "=== Weekly Insight KPIs ($cutoff_date to $today) ==="
    echo "Generated:  $generated"
    echo "Killed:     $killed"
    echo "Survived:   $survived"
    echo "Promoted:   $promoted"
    echo "Calibration: ${calibration_shift}% average confidence shift from prior"
}

main() {
    local command="${1:-help}"

    case "$command" in
        new)
            shift
            cmd_new "$@"
            ;;
        test-plan)
            shift
            cmd_test_plan "$@"
            ;;
        test-result)
            shift
            cmd_test_result "$@"
            ;;
        evidence)
            shift
            case "${1:-}" in
                add)
                    shift
                    cmd_evidence_add "$@"
                    ;;
                *)
                    echo "Error: Unknown evidence command '${1:-}'" >&2
                    echo "Usage: $(basename "$0") evidence add <hyp_id> [options]" >&2
                    return 1
                    ;;
            esac
            ;;
        verdict)
            shift
            cmd_verdict "$@"
            ;;
        weekly)
            shift
            cmd_weekly "$@"
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            echo "Error: Unknown command '$command'" >&2
            show_help >&2
            return 1
            ;;
    esac
}

main "$@"
