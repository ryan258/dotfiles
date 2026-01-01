#!/bin/bash

# scripts/lib/time_tracking.sh
# Shared library for time tracking functionality

# Default data directory if not set
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/date_utils.sh"

DATA_DIR="${DATA_DIR:-$HOME/.config/dotfiles-data}"
TIME_LOG="$DATA_DIR/time_tracking.txt"

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
    
    local task_text="${2:-}"
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
    local active_line=$(grep "^START" "$TIME_LOG" | tail -n 1)
    
    # If no start record found, or last record was STOP
    local last_line=$(tail -n 1 "$TIME_LOG" 2>/dev/null)
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

# Generate a report for a date range
# Usage: generate_time_report <start_date> <end_date>
generate_time_report() {
    # Placeholder for future implementation using awk or python for better reporting
    # TODO: Implement time reporting logic (see S2 roadmap)
    echo "Time Report feature not yet fully implemented"
}
