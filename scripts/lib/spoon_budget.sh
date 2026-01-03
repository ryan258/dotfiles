#!/bin/bash

# scripts/lib/spoon_budget.sh
# Shared library for Spoon Theory budget tracking

set -euo pipefail

DATA_DIR="${DATA_DIR:-$HOME/.config/dotfiles-data}"
SPOON_LOG="$DATA_DIR/spoons.txt"

mkdir -p "$DATA_DIR"

# Initialize daily spoon budget
# Usage: init_daily_spoons <count> [date]
init_daily_spoons() {
    local count="$1"

    # Validate count is a positive integer
    if ! [[ "$count" =~ ^[0-9]+$ ]]; then
        echo "Error: Count must be a positive integer" >&2
        return 1
    fi

    local date="${2:-$(date +%Y-%m-%d)}"
    
    # Check if already initialized
    if grep -q "^BUDGET|$date" "$SPOON_LOG" 2>/dev/null; then
        echo "Error: Budget already initialized for $date" >&2
        return 1
    fi
    
    echo "BUDGET|$date|$count" >> "$SPOON_LOG"
    echo "Initialized $count spoons for $date"
}

# Spend spoons on an activity
# Usage: spend_spoons <count> <activity>
spend_spoons() {
    local count="$1"
    
    # Validate count is a positive integer
    if ! [[ "$count" =~ ^[0-9]+$ ]]; then
        echo "Error: Count must be a positive integer" >&2
        return 1
    fi



    # Sanitize activity (remove pipes and newlines)
    local raw_activity="${2:-General Activity}"
    local activity=$(echo "$raw_activity" | tr -d '|\n' | head -c 100)
    local today=$(date +%Y-%m-%d)
    local time=$(date +%H:%M)
    
    # Get current remaining
    local remaining=$(get_remaining_spoons)
    
    # If no budget set, default to 12 if not found (or error?)
    # For now, let's assume we need a budget.
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
    local today=$(date +%Y-%m-%d)
    
    if [ ! -f "$SPOON_LOG" ]; then
        echo ""
        return
    fi
    
    # Find today's budget
    local budget_line=$(grep "^BUDGET|$today" "$SPOON_LOG" | tail -n 1)
    if [ -z "$budget_line" ]; then
        echo ""
        return
    fi
    
    local initial=$(echo "$budget_line" | cut -d'|' -f3)
    
    # Find last spend log for today to get remaining, 
    # OR sum up all spends. The spec says the log stores REMAINING, so we can just grab the last one.
    local last_spend=$(grep "^SPEND|$today" "$SPOON_LOG" | tail -n 1)
    
    if [ -n "$last_spend" ]; then
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

# Predict spoons for a date (Mock/placeholder for AI)
# Usage: predict_spoons_for_date <date>
predict_spoons_for_date() {
    local date="$1"
    # TODO: Implement prediction logic using correlation engine or AI
    echo "Prediction not implemented yet (requires AI)"
}

# Calculate cost for activity type
# Usage: calculate_activity_cost <activity_type>
calculate_activity_cost() {
    local type="$1"
    case "$type" in
        "meeting") echo 2 ;;
        "coding") echo 1 ;;
        "admin") echo 1 ;;
        "social") echo 3 ;;
        "travel") echo 4 ;;
        *) echo 1 ;;
    esac
}
