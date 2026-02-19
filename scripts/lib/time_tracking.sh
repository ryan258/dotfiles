#!/usr/bin/env bash
# scripts/lib/time_tracking.sh
# Shared library for time tracking functionality
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_TIME_TRACKING_LOADED:-}" ]]; then
    return 0
fi
readonly _TIME_TRACKING_LOADED=true

# Dependencies:
# - DATA_DIR/TIME_LOG from config.sh.
# - sanitize_input and sanitize_for_storage from common.sh.
# - timestamp_to_epoch and date_shift_days from date_utils.sh.
if [[ -z "${DATA_DIR:-}" ]]; then
    echo "Error: DATA_DIR is not set. Source scripts/lib/config.sh before time_tracking.sh." >&2
    return 1
fi
if ! command -v sanitize_input >/dev/null 2>&1; then
    echo "Error: sanitize_input is not available. Source scripts/lib/common.sh before time_tracking.sh." >&2
    return 1
fi
if ! command -v sanitize_for_storage >/dev/null 2>&1; then
    echo "Error: sanitize_for_storage is not available. Source scripts/lib/common.sh before time_tracking.sh." >&2
    return 1
fi
if ! command -v timestamp_to_epoch >/dev/null 2>&1; then
    echo "Error: timestamp_to_epoch is not available. Source scripts/lib/date_utils.sh before time_tracking.sh." >&2
    return 1
fi
if ! command -v date_shift_days >/dev/null 2>&1; then
    echo "Error: date_shift_days is not available. Source scripts/lib/date_utils.sh before time_tracking.sh." >&2
    return 1
fi

TIME_LOG="${TIME_LOG:-}"
if [[ -z "$TIME_LOG" ]]; then
    echo "Error: TIME_LOG is not set. Source scripts/lib/config.sh before time_tracking.sh." >&2
    return 1
fi

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Start a timer for a task
# Usage: start_timer <task_id> [task_text]
start_timer() {
    local task_id="$1"
    
    # Validate task_id doesn't contain pipe
    if [[ "$task_id" == *"|"* ]]; then
        echo "Error: Task ID cannot contain pipe character" >&2
        return 1
    fi
    
    task_id=$(sanitize_input "$task_id")
    task_id=${task_id//$'\n'/ }

    local task_text="${2:-}"
    task_text=$(sanitize_for_storage "$task_text")
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Check if a timer is already active
    local active=$(get_active_timer)
    if [ -n "$active" ]; then
        echo "Error: Timer already active for task $active. Stop it first." >&2
        return 1
    fi
    
    echo "START|$task_id|$task_text|$timestamp" >> "$TIME_LOG"
    echo "Started timer for task $task_id at $timestamp"
}

# Stop the active timer
# Usage: stop_timer [task_id]
stop_timer() {
    local task_id="${1:-}"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Get active timer details
    # Use || true to prevent set -e exit if grep finds nothing
    local active_line=$(grep "^START" "$TIME_LOG" 2>/dev/null | tail -n 1 || true)
    
    # If no start record found, or last record was STOP
    local last_line=$(tail -n 1 "$TIME_LOG" 2>/dev/null || true)
    if [[ -z "$active_line" ]] || [[ "$last_line" == STOP* ]]; then
        echo "Error: No active timer found." >&2
        return 1
    fi
    
    local active_id=$(echo "$active_line" | cut -d'|' -f2)
    local active_start_time=$(echo "$active_line" | cut -d'|' -f4)
    
    # If task_id provided, verify it matches
    if [ -n "$task_id" ] && [ "$task_id" != "$active_id" ]; then
        echo "Error: Active timer is for task $active_id, not $task_id." >&2
        return 1
    fi
    
    echo "STOP|$active_id|$timestamp" >> "$TIME_LOG"
    
    # Calculate duration
    local start_ts=$(timestamp_to_epoch "$active_start_time")
    local end_ts=$(timestamp_to_epoch "$timestamp")
    local duration=$((end_ts - start_ts))
    
    echo "Stopped timer for task $active_id. Duration: $(format_duration $duration)"
}

# Get the ID of the currently active task, if any
# Usage: get_active_timer
get_active_timer() {
    if [ ! -f "$TIME_LOG" ]; then
        return 0
    fi
    
    local last_line=$(tail -n 1 "$TIME_LOG")
    if [[ "$last_line" == START* ]]; then
        echo "$last_line" | cut -d'|' -f2
    fi
}

# Get total time spent on a task
# Usage: get_task_time <task_id>
get_task_time() {
    local task_id="$1"
    local total_seconds=0
    
    if [ ! -f "$TIME_LOG" ]; then
        echo "0"
        return 0
    fi
    
    # Read file line by line to calculate time
    # This is a simple implementation; for large files, python might be better
    local start_time=0
    
    while IFS='|' read -r type id p3 p4; do
        local timestamp=""
        if [ "$id" == "$task_id" ]; then
            if [ "$type" == "START" ]; then
                timestamp="$p4"
            elif [ "$type" == "STOP" ]; then
                timestamp="$p3"
            fi
            
            if [ -n "$timestamp" ]; then
                local ts=$(timestamp_to_epoch "$timestamp")
                
                if [ "$type" == "START" ]; then
                    start_time=$ts
                elif [ "$type" == "STOP" ] && [ $start_time -gt 0 ]; then
                    local duration=$((ts - start_time))
                    total_seconds=$((total_seconds + duration))
                    start_time=0
                fi
            fi
        fi
    done < "$TIME_LOG"
    
    # If currently running, add elapsed time
    local active_id=$(get_active_timer)
    if [ "$active_id" == "$task_id" ]; then
        # Need to find the last start time for this task
        local last_start=$(grep "^START|$task_id" "$TIME_LOG" | tail -n 1 | cut -d'|' -f4)
        local start_ts=$(timestamp_to_epoch "$last_start")
        local now_ts=$(date +%s)
        local elapsed=$((now_ts - start_ts))
        total_seconds=$((total_seconds + elapsed))
    fi
    
    echo "$total_seconds"
}

# Format seconds into HH:MM:SS
# Usage: format_duration <seconds>
format_duration() {
    local total_seconds="$1"
    local hours=$((total_seconds / 3600))
    local minutes=$(( (total_seconds % 3600) / 60 ))
    local seconds=$((total_seconds % 60))
    
    printf "%02d:%02d:%02d" $hours $minutes $seconds
}

# Check if a date is within a range (inclusive)
# Usage: date_in_range <date> <start> <end>
date_in_range() {
    local date="$1"
    local start="$2"
    local end="$3"

    if [[ "$date" < "$start" ]] || [[ "$date" > "$end" ]]; then
        return 1
    fi
    return 0
}

# Get total tracked seconds for a specific date (YYYY-MM-DD)
# Usage: get_total_time_for_date <date>
get_total_time_for_date() {
    local target_date="$1"

    if [[ -z "$target_date" ]]; then
        echo "0"
        return
    fi

    if [ ! -f "$TIME_LOG" ]; then
        echo "0"
        return
    fi

    local total_seconds=0
    declare -A start_ts_by_id
    declare -A start_date_by_id

    while IFS='|' read -r type id p3 p4; do
        if [ "$type" == "START" ]; then
            local timestamp="$p4"
            local date_part="${timestamp%% *}"
            start_ts_by_id["$id"]="$timestamp"
            start_date_by_id["$id"]="$date_part"
        elif [ "$type" == "STOP" ]; then
            if [[ -n "${start_ts_by_id[$id]:-}" ]]; then
                local start_ts="${start_ts_by_id[$id]}"
                local date_part="${start_date_by_id[$id]}"
                local stop_ts="$p3"

                if [ "$date_part" == "$target_date" ]; then
                    local start_epoch
                    local stop_epoch
                    start_epoch=$(timestamp_to_epoch "$start_ts")
                    stop_epoch=$(timestamp_to_epoch "$stop_ts")
                    if [ "$stop_epoch" -gt "$start_epoch" ] && [ "$start_epoch" -gt 0 ]; then
                        total_seconds=$((total_seconds + (stop_epoch - start_epoch)))
                    fi
                fi
                unset start_ts_by_id["$id"]
                unset start_date_by_id["$id"]
            fi
        fi
    done < "$TIME_LOG"

    # Include currently active timers that started today
    local now_epoch
    now_epoch=$(date +%s)
    for id in "${!start_ts_by_id[@]}"; do
        local start_ts="${start_ts_by_id[$id]}"
        local date_part="${start_date_by_id[$id]}"
        if [ "$date_part" == "$target_date" ]; then
            local start_epoch
            start_epoch=$(timestamp_to_epoch "$start_ts")
            if [ "$start_epoch" -gt 0 ] && [ "$now_epoch" -gt "$start_epoch" ]; then
                total_seconds=$((total_seconds + (now_epoch - start_epoch)))
            fi
        fi
    done

    echo "$total_seconds"
}

# Generate a report for a date range
# Usage: generate_time_report <start_date> <end_date>
generate_time_report() {
    local start_date=""
    local end_date=""
    local days=7
    local summary=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --days)
                if [[ -z "${2:-}" ]] || [[ "${2:-}" == --* ]]; then
                    echo "Error: --days requires a numeric value." >&2
                    return 1
                fi
                days="$2"
                shift 2
                ;;
            --summary)
                summary=true
                shift
                ;;
            *)
                if [[ -z "$start_date" ]]; then
                    start_date="$1"
                elif [[ -z "$end_date" ]]; then
                    end_date="$1"
                fi
                shift
                ;;
        esac
    done

    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo "Error: --days must be a number." >&2
        return 1
    fi

    if [[ -z "$end_date" ]]; then
        end_date=$(date +%Y-%m-%d)
    fi
    if [[ -z "$start_date" ]]; then
        if [ "$days" -lt 1 ]; then
            days=1
        fi
        local offset=$((days - 1))
        start_date=$(date_shift_days "-$offset" "%Y-%m-%d")
    fi

    if [[ "$start_date" > "$end_date" ]]; then
        local tmp="$start_date"
        start_date="$end_date"
        end_date="$tmp"
    fi

    if [ ! -f "$TIME_LOG" ]; then
        echo "No time log found at $TIME_LOG" >&2
        return 0
    fi

    declare -A day_total
    declare -A task_total
    declare -A task_desc
    declare -A start_ts_by_id
    declare -A start_date_by_id
    declare -A start_desc_by_id

    while IFS='|' read -r type id p3 p4; do
        if [ "$type" == "START" ]; then
            local start_ts="$p4"
            local date_part="${start_ts%% *}"
            start_ts_by_id["$id"]="$start_ts"
            start_date_by_id["$id"]="$date_part"
            start_desc_by_id["$id"]="$p3"
        elif [ "$type" == "STOP" ]; then
            if [[ -n "${start_ts_by_id[$id]:-}" ]]; then
                local start_ts="${start_ts_by_id[$id]}"
                local date_part="${start_date_by_id[$id]}"
                local stop_ts="$p3"

                if date_in_range "$date_part" "$start_date" "$end_date"; then
                    local start_epoch
                    local stop_epoch
                    start_epoch=$(timestamp_to_epoch "$start_ts")
                    stop_epoch=$(timestamp_to_epoch "$stop_ts")
                    if [ "$stop_epoch" -gt "$start_epoch" ] && [ "$start_epoch" -gt 0 ]; then
                        local duration=$((stop_epoch - start_epoch))
                        day_total["$date_part"]=$(( ${day_total["$date_part"]:-0} + duration ))
                        task_total["$id"]=$(( ${task_total["$id"]:-0} + duration ))
                        task_desc["$id"]="${start_desc_by_id[$id]:-}"
                    fi
                fi
                unset start_ts_by_id["$id"]
                unset start_date_by_id["$id"]
                unset start_desc_by_id["$id"]
            fi
        fi
    done < "$TIME_LOG"

    # Include currently active timers
    local now_epoch
    now_epoch=$(date +%s)
    for id in "${!start_ts_by_id[@]}"; do
        local start_ts="${start_ts_by_id[$id]}"
        local date_part="${start_date_by_id[$id]}"
        if date_in_range "$date_part" "$start_date" "$end_date"; then
            local start_epoch
            start_epoch=$(timestamp_to_epoch "$start_ts")
            if [ "$start_epoch" -gt 0 ] && [ "$now_epoch" -gt "$start_epoch" ]; then
                local duration=$((now_epoch - start_epoch))
                day_total["$date_part"]=$(( ${day_total["$date_part"]:-0} + duration ))
                task_total["$id"]=$(( ${task_total["$id"]:-0} + duration ))
                task_desc["$id"]="${start_desc_by_id[$id]:-}"
            fi
        fi
    done

    if [ "$summary" = true ]; then
        local total=0
        for d in "${!day_total[@]}"; do
            total=$((total + day_total["$d"]))
        done
        echo "$(format_duration "$total")"
        return 0
    fi

    echo "Time Report: $start_date → $end_date"
    echo ""
    echo "By day:"
    local total_seconds=0
    if [ "${#day_total[@]}" -eq 0 ]; then
        echo "  (No tracked time in range)"
    else
        for d in $(printf "%s\n" "${!day_total[@]}" | sort); do
            local duration="${day_total[$d]}"
            total_seconds=$((total_seconds + duration))
            echo "  $d  $(format_duration "$duration")"
        done
    fi

    echo ""
    echo "Total: $(format_duration "$total_seconds")"

    if [ "${#task_total[@]}" -gt 0 ]; then
        echo ""
        echo "Top tasks:"
        printf "%s\n" "${!task_total[@]}" | while read -r id; do
            local duration="${task_total[$id]}"
            local desc="${task_desc[$id]}"
            if [ -n "$desc" ]; then
                echo "$duration|$id - $desc"
            else
                echo "$duration|$id"
            fi
        done | sort -t'|' -nr | head -n 5 | while IFS='|' read -r duration label; do
            echo "  $(format_duration "$duration")  $label"
        done
    fi
}
