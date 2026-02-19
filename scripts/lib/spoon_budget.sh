#!/usr/bin/env bash
# scripts/lib/spoon_budget.sh
# Shared library for Spoon Theory budget tracking
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_SPOON_BUDGET_LOADED:-}" ]]; then
    return 0
fi
readonly _SPOON_BUDGET_LOADED=true

# Dependencies:
# - DATA_DIR/SPOON_LOG/DEFAULT_DAILY_SPOONS from config.sh.
# - validate_numeric and sanitize_for_storage from common.sh.
if [[ -z "${DATA_DIR:-}" ]]; then
    echo "Error: DATA_DIR is not set. Source scripts/lib/config.sh before spoon_budget.sh." >&2
    return 1
fi
if ! command -v validate_numeric >/dev/null 2>&1; then
    echo "Error: validate_numeric is not available. Source scripts/lib/common.sh before spoon_budget.sh." >&2
    return 1
fi
if ! command -v sanitize_for_storage >/dev/null 2>&1; then
    echo "Error: sanitize_for_storage is not available. Source scripts/lib/common.sh before spoon_budget.sh." >&2
    return 1
fi

SPOON_LOG="${SPOON_LOG:-}"
if [[ -z "$SPOON_LOG" ]]; then
    echo "Error: SPOON_LOG is not set. Source scripts/lib/config.sh before spoon_budget.sh." >&2
    return 1
fi

# Cross-platform date helper: prefer date_today from date_utils.sh if loaded
_spoon_today() {
    if command -v date_today >/dev/null 2>&1; then
        date_today
    else
        date +%Y-%m-%d
    fi
}

mkdir -p "$DATA_DIR"

# Initialize daily spoon budget
# Usage: init_daily_spoons <count> [date]
init_daily_spoons() {
    local count="${1:-$DEFAULT_DAILY_SPOONS}"

    validate_numeric "$count" "spoon count" || return 1

    local date="${2:-$(_spoon_today)}"
    
    # Check if already initialized
    if grep -q "^BUDGET|$date" "$SPOON_LOG" 2>/dev/null; then
        echo "Error: Budget already initialized for $date" >&2
        return 1
    fi
    
    echo "BUDGET|$date|$count" >> "$SPOON_LOG"
    echo "Initialized $count spoons for $date"
}

# Set (override) daily spoon budget
# Usage: set_daily_spoons <count> [date]
set_daily_spoons() {
    local count="${1:-$DEFAULT_DAILY_SPOONS}"

    validate_numeric "$count" "spoon count" || return 1

    local date="${2:-$(_spoon_today)}"

    echo "BUDGET|$date|$count" >> "$SPOON_LOG"
    echo "Updated budget to $count spoons for $date"
}

# Spend spoons on an activity
# Usage: spend_spoons <count> <activity>
spend_spoons() {
    local count="$1"

    validate_numeric "$count" "spoon count" || return 1

    # Sanitize activity
    local raw_activity="${2:-General Activity}"
    local activity
    activity=$(sanitize_for_storage "$raw_activity")
    activity=$(printf '%s' "$activity" | head -c 100)
    local today=$(_spoon_today)
    local time
    if command -v date_now >/dev/null 2>&1; then
        time=$(date_now "%H:%M")
    else
        time=$(date +%H:%M)
    fi
    
    # Get current remaining
    local remaining=$(get_remaining_spoons)
    
    # If no budget set, we require initialization first.
    if [ -z "$remaining" ]; then
        echo "Error: No spoon budget initialized for today ($today)" >&2
        return 1
    fi
    
    local new_remaining=$((remaining - count))
    
    echo "SPEND|$today|$time|$count|$activity|$new_remaining" >> "$SPOON_LOG"
    
    if [ $new_remaining -lt 0 ]; then
        echo "Warning: You are in spoon debt! ($new_remaining left)"
    else
        echo "Spent $count spoons. $new_remaining remaining."
    fi
}

# Get remaining spoons for today
# Usage: get_remaining_spoons
get_remaining_spoons() {
    local today=$(_spoon_today)
    
    if [ ! -f "$SPOON_LOG" ]; then
        echo ""
        return
    fi
    
    # Find today's budget (track line numbers for ordering)
    local budget_line_info
    budget_line_info=$(grep -n "^BUDGET|$today" "$SPOON_LOG" | tail -n 1 || true)
    local budget_line="${budget_line_info#*:}"
    if [ -z "$budget_line" ]; then
        echo ""
        return
    fi
    
    local budget_line_num="${budget_line_info%%:*}"
    local initial=$(echo "$budget_line" | cut -d'|' -f3)
    
    # Find last spend log for today to get remaining, 
    # OR sum up all spends. The spec says the log stores REMAINING, so we can just grab the last one.
    local last_spend_info
    last_spend_info=$(grep -n "^SPEND|$today" "$SPOON_LOG" | tail -n 1 || true)
    local last_spend="${last_spend_info#*:}"
    local last_spend_line_num="${last_spend_info%%:*}"

    if [ -n "$last_spend" ] && [ -n "$last_spend_line_num" ] && [ "$last_spend_line_num" -gt "$budget_line_num" ]; then
        echo "$last_spend" | cut -d'|' -f6
    else
        echo "$initial"
    fi
}

# Get spoon history for last N days
# Usage: get_spoon_history <days>
get_spoon_history() {
    local days="${1:-7}"
    
    echo "=== Spoon History (Last $days days) ==="
    echo "Date       Budget     Used Remaining"
    echo "---------- ------     ---- ---------"
    
    if [ ! -f "$SPOON_LOG" ] || [ ! -s "$SPOON_LOG" ]; then
         echo "No spoon history found."
         return 0
    fi
    
    # We need to process unique dates from the log
    # Sort | Uniq | tail -n days
    
    local relevant_dates
    relevant_dates=$(grep "BUDGET" "$SPOON_LOG" | cut -d'|' -f2 | sort -u | tail -n "$days")
    
    while IFS= read -r date; do
        if [ -z "$date" ]; then continue; fi
        
        # Get budget
        local budget_line=$(grep "^BUDGET|$date" "$SPOON_LOG" | tail -n 1)
        local budget=$(echo "$budget_line" | cut -d'|' -f3)
        
        # Get final remaining for that day
        local last_spend=$(grep "^SPEND|$date" "$SPOON_LOG" | tail -n 1)
        local remaining="$budget"
        if [ -n "$last_spend" ]; then
            remaining=$(echo "$last_spend" | cut -d'|' -f6)
        fi
        
        # Calculate used
        local used=$((budget - remaining))
        
        printf "%-10s %6s %8s %9s\n" "$date" "$budget" "$used" "$remaining"
        
    done <<< "$relevant_dates"
}
