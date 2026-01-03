#!/bin/bash

# scripts/spoon_manager.sh
# CLI Wrapper for Spoon Theory budget tracking
# Log Format (spoons.txt):
# BUDGET|YYYY-MM-DD|count
# SPEND|YYYY-MM-DD|HH:MM|count|activity|remaining

set -euo pipefail

# Source the shared library
source "$(dirname "${BASH_SOURCE[0]}")/lib/spoon_budget.sh"

show_help() {
    echo "Usage: $(basename "$0") {init|spend|check|history|cost}"
    echo ""
    echo "Commands:"
    echo "  init <count>                   Initialize daily spoons (default: 12)"
    echo "  spend <count> [activity]       Spend spoons on an activity"
    echo "  check                          Show remaining spoons"
    echo "  history [days]                 Show spoon history (default: 7 days)"
    echo "  cost <activity_type>           Show standard cost for activity type"
}

case "${1:-}" in
    init)
        count="${2:-12}"
        if ! [[ "$count" =~ ^[0-9]+$ ]]; then
             echo "Error: Count must be a positive integer" >&2
             exit 1
        fi
        init_daily_spoons "$count"
        ;;
    spend)
        if [ -z "${2:-}" ]; then
            echo "Error: Spoon count required" >&2
            echo "Usage: $(basename "$0") spend <count> [activity]" >&2
            exit 1
        fi
        spend_spoons "$2" "${3:-General Activity}"
        ;;
    check)
        remaining=$(get_remaining_spoons)
        if [ -n "$remaining" ]; then
            echo "Remaining spoons: $remaining"
        else
            echo "No spoon budget found for today."
            exit 1
        fi
        ;;
    history)
        get_spoon_history "${2:-7}"
        ;;
    cost)
        if [ -z "${2:-}" ]; then
            echo "Error: Activity type required" >&2
            echo "Usage: $(basename "$0") cost <type>" >&2
            exit 1
        fi
        cost=$(calculate_activity_cost "$2")
        echo "Standard cost for '$2': $cost"
        ;;
    *)
        show_help
        exit 1
        ;;
esac
