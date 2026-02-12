#!/usr/bin/env bash

# scripts/generate_report.sh
# Generates daily/weekly summaries and correlations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_LIB="$SCRIPT_DIR/lib/common.sh"
CONFIG_LIB="$SCRIPT_DIR/lib/config.sh"
DATE_UTILS="$SCRIPT_DIR/lib/date_utils.sh"

if [ -f "$COMMON_LIB" ]; then
    # shellcheck disable=SC1090
    source "$COMMON_LIB"
else
    echo "Error: common utilities not found at $COMMON_LIB" >&2
    exit 1
fi

if [ -f "$CONFIG_LIB" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_LIB"
else
    echo "Error: configuration library not found at $CONFIG_LIB" >&2
    exit 1
fi
if [ -f "$DATE_UTILS" ]; then
    # shellcheck disable=SC1090
    source "$DATE_UTILS"
else
    die "date utilities not found at $DATE_UTILS" "$EXIT_FILE_NOT_FOUND"
fi

REPORTS_DIR=$(validate_path "$REPORTS_DIR") || die "Invalid reports directory path: $REPORTS_DIR" "$EXIT_INVALID_ARGS"
mkdir -p "$REPORTS_DIR"

CORRELATE_CMD="$SCRIPT_DIR/correlate.sh"

REPORT_TYPE_RAW="${1:-daily}"
REPORT_TYPE=$(sanitize_input "$REPORT_TYPE_RAW")
REPORT_TYPE=${REPORT_TYPE//$'\n'/ }
if ! [[ "$REPORT_TYPE" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Error: Invalid report type '$REPORT_TYPE'." >&2
    echo "Use letters, numbers, '.', '_' or '-' only." >&2
    exit 1
fi

TODAY=$(date_today)
REPORT_FILE="$REPORTS_DIR/report-$REPORT_TYPE-$TODAY.md"
REPORT_FILE=$(validate_path "$REPORT_FILE") || die "Invalid report output path: $REPORT_FILE" "$EXIT_INVALID_ARGS"

# Use existing libraries for consistent logic and date handling
TIME_LIB="$SCRIPT_DIR/lib/time_tracking.sh"

if [ -f "$TIME_LIB" ]; then source "$TIME_LIB"; fi

# Helper to aggregate time duration for a specific date
aggregate_daily_time() {
    local date="$1"
    if [ ! -f "$TIME_LOG" ]; then echo "0"; return; fi

    # Calculate total seconds
    # Use associative array to track start times by task ID
    # Format: START|id|description|timestamp, STOP|id|timestamp
    local total=0
    declare -A start_times

    while IFS='|' read -r type id rest; do
        if [ "$type" == "START" ]; then
            # rest is "description|timestamp", extract last field
            local timestamp="${rest##*|}"
            start_times[$id]=$(timestamp_to_epoch "$timestamp")
        elif [ "$type" == "STOP" ]; then
            # rest is just "timestamp"
            local stop_time
            stop_time=$(timestamp_to_epoch "$rest")
            if [ -n "${start_times[$id]:-}" ] && [ "$stop_time" -gt "${start_times[$id]}" ] && [ "${start_times[$id]}" -gt 0 ]; then
                total=$((total + (stop_time - start_times[$id])))
            fi
            unset start_times[$id]
        fi
    done < <(grep "|$date " "$TIME_LOG" 2>/dev/null || true)

    echo "$total"
}

aggregate_daily_spoons() {
    local date="$1"
    if [ ! -f "$SPOON_LOG" ]; then echo "0"; return; fi
    # Sum of spoons spent
    grep "^SPEND|$date" "$SPOON_LOG" 2>/dev/null | cut -d'|' -f4 | awk '{s+=$1} END {print s+0}' || echo "0"
}

# --- Report Generation ---

echo "# $REPORT_TYPE Report for $TODAY" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "## ⏱️ Time Tracking" >> "$REPORT_FILE"
total_seconds=$(aggregate_daily_time "$TODAY")
hours=$((total_seconds / 3600))
mins=$(( (total_seconds % 3600) / 60 ))
echo "**Total Focus Time:** ${hours}h ${mins}m" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "## 🥣 Spoon Budget" >> "$REPORT_FILE"
# Reuse existing stats helper logic but inline for simplicity now
spoon_budget=$(grep "^BUDGET|$TODAY" "$SPOON_LOG" 2>/dev/null | tail -n1 | cut -d'|' -f3 || echo "0")
if [ "$spoon_budget" == "0" ]; then
    echo "No data" >> "$REPORT_FILE"
else
    spoon_spent=$(aggregate_daily_spoons "$TODAY")
    spoon_remaining=$(grep "^SPEND|$TODAY" "$SPOON_LOG" 2>/dev/null | tail -n1 | cut -d'|' -f6 || echo "$spoon_budget")
    echo "Budget: $spoon_budget | Spent: $spoon_spent | Remaining: $spoon_remaining" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

echo "## 📊 Correlations (Experimental)" >> "$REPORT_FILE"
if [ -x "$CORRELATE_CMD" ]; then
    # Generate aggregated CSVs for last 7 days to find correlations
    AGG_TIME="$REPORTS_DIR/agg_time.csv"
    AGG_SPOONS="$REPORTS_DIR/agg_spoons.csv"
    
    # Header required for correlate.py? No, it takes column indices.
    # But usually CSVs have headers.
    
    > "$AGG_TIME"
    > "$AGG_SPOONS"
    
    # Loop last 7 days
    for i in {0..6}; do
        d=$(date_days_ago "$i")
        
        t=$(aggregate_daily_time "$d")
        t_mins=$((t / 60))
        echo "$d|$t_mins" >> "$AGG_TIME"
        
        s=$(aggregate_daily_spoons "$d")
        echo "$d|$s" >> "$AGG_SPOONS"
    done
    
    # Run correlation: File1=Spoons(1), File2=Time(1)
    # Col 0 is Date, Col 1 is Value
    
    correlation=$("$CORRELATE_CMD" run "$AGG_SPOONS" "$AGG_TIME" 0 1 0 1 2>/dev/null || echo "N/A")
    
    # Check if a valid number
    if [[ "$correlation" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
        echo "**Spoons Spent vs Focus Time:** r=$correlation" >> "$REPORT_FILE"
    else
         echo "Not enough data for correlation." >> "$REPORT_FILE"
    fi
else
    echo "Correlation engine not found." >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo "Report generated at $(date_now)" >> "$REPORT_FILE"

echo "Report generated: $REPORT_FILE"
cat "$REPORT_FILE"
